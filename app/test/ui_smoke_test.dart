import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:onestep/core/domain/providers.dart';
import 'package:onestep/features/browser/browser_screen.dart';
import 'package:onestep/features/deck/deck_detail_screen.dart';
import 'package:onestep/features/review/review_screen.dart';
import 'package:onestep/features/settings/settings_screen.dart';
import 'package:onestep/features/shell/root_shell.dart';
import 'package:onestep/features/sync/sync_screen.dart';
import 'package:onestep/shared/theme/app_theme.dart';
import 'package:onestep/shared/widgets/ink.dart';

/// 界面真渲染冒烟测试。
///
/// 为什么需要它：`flutter analyze` 只查类型与 lint，单元测试只跑纯逻辑，
/// 两者都发现不了"某个屏在手机上溢出 12 像素"或"provider 没挂上导致白屏"。
/// 这里把每一屏在**手机尺寸**和**桌面尺寸**下真的 build + layout + paint 一遍：
/// RenderFlex overflow、空引用、缺失 Provider 都会在这一步抛错并让测试变红。
void main() {
  late OnestepDb db;
  late CollectionRepo repo;
  late String deckId;

  setUp(() async {
    db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    repo = CollectionRepo(db);
    deckId = (await repo.allDecks()).first.id;

    // 造一点真实数据：基本卡 + 完形卡 + 第二个分组，保证列表不是空的。
    await repo.createBasicNote(deckId: deckId, front: '积跬步', back: '无以至千里');
    await repo.createBasicNote(deckId: deckId, front: '锲而不舍', back: '金石可镂');
    await repo.createClozeNote(deckId: deckId, text: '水在{{c1::100}}度沸腾');
    await repo.createDeck('英语单词');
    final other = (await repo.allDecks()).last;
    await repo.createBasicNote(
        deckId: other.id, front: 'abandon', back: 'v. 放弃');
  });

  tearDown(() async => db.close());

  /// 按给定逻辑尺寸挂载一个 widget。
  Future<void> mount(WidgetTester tester, Widget child, Size size,
      {Brightness brightness = Brightness.light,
      List<Override> overrides = const []}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db), ...overrides],
        child: MaterialApp(
          theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    final tag = size.width < 500 ? '手机' : '桌面';

    testWidgets('$tag：外壳四栏导航都能渲染并切页', (tester) async {
      await mount(tester, const RootShell(), size);
      expect(find.text('跬步'), findsOneWidget);
      expect(find.text('我的分组'), findsOneWidget);
      expect(find.text('开始学习'), findsOneWidget);
      // 添加口在下方导航，右上角不再放 +。
      expect(find.text('添加'), findsOneWidget);
      expect(find.byTooltip('添加卡片'), findsNothing);

      // 切到统计、我的，再切回首页。
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      expect(find.text('近 7 天复习量'), findsOneWidget);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(find.text('学习设置'), findsWidgets);
      expect(find.text('多设备同步'), findsWidgets);

      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      // 首页列的是分组，不是卡片（卡片要进详情页才看得到）。
      expect(find.text('默认牌组'), findsOneWidget);
      expect(find.text('英语单词'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag：复习页翻面与四档打分不溢出', (tester) async {
      await mount(
        tester,
        ReviewScreen(deckId: deckId, deckName: '默认牌组'),
        size,
      );
      expect(find.text('显示答案'), findsOneWidget);

      await tester.tap(find.text('显示答案'));
      await tester.pumpAndSettle();
      for (final label in ['忘记', '困难', '良好', '简单']) {
        expect(find.text(label), findsOneWidget, reason: '四档评分按钮必须都在');
      }

      await tester.tap(find.text('良好'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag：复习页答完出现印章完成页', (tester) async {
      await mount(tester, ReviewScreen(deckId: deckId, deckName: '默认牌组'), size);
      // 队列里共 3 张（2 基本 + 1 完形），全部打完进入完成页。
      for (var i = 0; i < 4; i++) {
        if (find.text('显示答案').evaluate().isEmpty) break;
        await tester.tap(find.text('显示答案'));
        await tester.pumpAndSettle();
        if (find.text('良好').evaluate().isEmpty) break;
        await tester.tap(find.text('良好'));
        await tester.pumpAndSettle();
      }
      expect(find.text('返回分组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag：牌组详情页（头卡 + 筛选 + 网格）', (tester) async {
      await mount(
        tester,
        DeckDetailScreen(deckId: deckId, deckName: '默认牌组'),
        size,
      );
      expect(find.text('卡片'), findsOneWidget);
      expect(find.text('记忆中'), findsOneWidget);
      expect(find.text('abandon'), findsNothing); // 只列本组卡片

      await tester.tap(find.text('未学'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag：卡片浏览器（搜索 + 筛选 chip）', (tester) async {
      await mount(tester, const BrowserScreen(), size);
      expect(find.text('浏览卡片'), findsOneWidget);
      expect(find.text('全部'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '跬');
      await tester.pumpAndSettle();
      expect(find.text('积跬步'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '不存在xyz');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的卡片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag：设置页与同步页', (tester) async {
      await mount(tester, const SettingsScreen(), size);
      expect(find.text('新卡上限'), findsOneWidget);
      expect(find.text('期望记忆保持率'), findsOneWidget);

      await mount(tester, const SyncScreen(), size);
      expect(find.text('同步服务器地址'), findsOneWidget);
      expect(find.text('立即同步'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag：暗色下首页同样可渲染', (tester) async {
      await mount(tester, const RootShell(), size, brightness: Brightness.dark);
      expect(find.text('跬步'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('空分组不得谎报"已清空"，应引导去添加', (tester) async {
    await repo.createDeck('空组');
    final emptyDeck = (await repo.allDecks()).last;

    // 只在详情页断言：首页分组卡在小屏可能落在折叠线以下。
    await mount(
      tester,
      DeckDetailScreen(deckId: emptyDeck.id, deckName: emptyDeck.name),
      const Size(390, 844),
    );
    expect(find.text('空分组'), findsOneWidget, reason: '状态徽标要说"空"，不是"已清空"');
    expect(find.text('已清空'), findsNothing);
    expect(find.text('这个分组还没有卡片。'), findsOneWidget);
    expect(find.text('添加卡片到本组'), findsOneWidget);
    expect(find.text('本组今日已学完'), findsNothing);
    // 空分组头卡不再重复放"添加"按钮，底部那一个就是唯一入口。
    expect(find.text('开始学习'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('学完但仍有卡片时显示"本组今日已学完"', (tester) async {
    // 把默认组的 3 张全部打完 -> due 归零、total 仍为 3。
    final review = ReviewScreen(deckId: deckId, deckName: '默认牌组');
    await mount(tester, review, const Size(390, 844));
    for (var i = 0; i < 4; i++) {
      if (find.text('显示答案').evaluate().isEmpty) break;
      await tester.tap(find.text('显示答案'));
      await tester.pumpAndSettle();
      if (find.text('良好').evaluate().isEmpty) break;
      await tester.tap(find.text('良好'));
      await tester.pumpAndSettle();
    }
    // 注意：这里不点"返回分组"——测试里 ReviewScreen 是 home 路由，
    // pop 根路由会触发 Navigator._history.isNotEmpty 断言（真实应用里它总是被 push）。
    // 复习页已把状态写进同一个 db，直接重挂详情页即可。

    final decks = await repo.allDecks();
    final def = decks.firstWhere((d) => d.name == '默认牌组');
    await mount(
      tester,
      DeckDetailScreen(deckId: def.id, deckName: def.name),
      const Size(390, 844),
    );
    expect(find.text('本组今日已学完'), findsOneWidget);
    expect(find.text('开始学习'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同步页回填上次保存的地址与账号（下次进来不用重填）', (tester) async {
    repo.syncServerUrl = 'http://172.31.32.1:8787';
    repo.syncUsername = 'ian';
    repo.syncSecret = 'pw123456';
    await repo.saveSyncSettings();

    // 模拟应用重启：新实例从库里加载，再注入 repoProvider。
    final restarted = CollectionRepo(db);
    await restarted.loadSettings();

    await mount(
      tester,
      const SyncScreen(),
      const Size(390, 844),
      overrides: [repoProvider.overrideWithValue(restarted)],
    );
    expect(find.text('http://172.31.32.1:8787'), findsOneWidget);
    expect(find.text('ian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('失焦即保存：改完地址点别处，新实例能读到', (tester) async {
    await mount(tester, const SyncScreen(), const Size(390, 844));

    await tester.enterText(find.byType(TextField).first, 'http://172.31.32.1:8787');
    // 把焦点移到账号框 -> 地址框失焦，触发落库
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();

    final reloaded = CollectionRepo(db);
    await reloaded.loadSettings();
    expect(reloaded.syncServerUrl, 'http://172.31.32.1:8787');
  });

  testWidgets('记住了登录状态时同步页显示"已登录"，且同步按钮不再被禁用', (tester) async {
    repo.syncServerUrl = 'http://172.31.32.1:8787';
    repo.syncUsername = 'ian';
    repo.syncSecret = 'pw123456';
    repo.syncToken = 'tok-from-last-run';
    repo.syncAccountId = 'acct_1';
    await repo.saveSyncSettings();

    final restarted = CollectionRepo(db);
    await restarted.loadSettings();

    await mount(
      tester,
      const SyncScreen(),
      const Size(390, 844),
      overrides: [repoProvider.overrideWithValue(restarted)],
    );
    expect(find.textContaining('已登录'), findsOneWidget);

    // 只断言按钮可用，不真的点它：widget test 跑在 FakeAsync 里，
    // 真实网络 I/O 不会被 pump 推动，点下去会假超时。
    final btn = tester.widget<InkButton>(
      find.ancestor(
        of: find.text('立即同步'),
        matching: find.byType(InkButton),
      ),
    );
    expect(btn.onPressed, isNotNull,
        reason: '有记住的会话时不该再要求先点登录');
    expect(tester.takeException(), isNull);
  });

  testWidgets('未登录时同步页显示"未登录"', (tester) async {
    await mount(tester, const SyncScreen(), const Size(390, 844));
    expect(find.textContaining('未登录'), findsOneWidget);
    expect(find.textContaining('已登录'), findsNothing);
  });

  /// 定位某个分组卡上的「分组操作」菜单（按名字，不靠列表下标猜顺序）。
  Finder menuOf(String deckName) => find.descendant(
        of: find.ancestor(
            of: find.text(deckName), matching: find.byType(InkCard)),
        matching: find.byTooltip('分组操作'),
      );

  testWidgets('首页按层级缩进渲染，父组数字聚合子树', (tester) async {
    final root = await repo.createDeck('大模型');
    final child = await repo.createDeck('深度学习', parentId: root.id);
    await repo.createBasicNote(deckId: child.id, front: 'cq', back: 'a');

    await mount(tester, const RootShell(), const Size(390, 844));
    expect(find.text('大模型'), findsOneWidget);
    expect(find.text('深度学习'), findsOneWidget);

    // 缩进：子分组必须比父分组更靠右。
    final rootX = tester.getTopLeft(find.ancestor(
            of: find.text('大模型'), matching: find.byType(InkCard)))
        .dx;
    final childX = tester.getTopLeft(find.ancestor(
            of: find.text('深度学习'), matching: find.byType(InkCard)))
        .dx;
    expect(childX, greaterThan(rootX), reason: '层级要一眼可见');

    // 折叠：点箭头收起后子分组消失，再点回来。
    await tester.tap(find.byTooltip('收起子分组'));
    await tester.pumpAndSettle();
    expect(find.text('深度学习'), findsNothing);
    await tester.tap(find.byTooltip('展开子分组'));
    await tester.pumpAndSettle();
    expect(find.text('深度学习'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('第 5 层的"新建子分组"置灰并写明原因', (tester) async {
    var parentId = (await repo.allDecks()).first.id; // 默认牌组 = 第 1 层
    for (var level = 2; level <= 5; level++) {
      parentId = (await repo.createDeck('L$level', parentId: parentId)).id;
    }

    await mount(tester, const RootShell(), const Size(1280, 800));
    // 最深的行在视口外，先滚过去再点。
    await tester.ensureVisible(menuOf('L5'));
    await tester.pumpAndSettle();
    await tester.tap(menuOf('L5'));
    await tester.pumpAndSettle();

    expect(find.text('已达 5 层'), findsOneWidget);
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
          of: find.text('新建子分组'),
          matching: find.byType(PopupMenuItem<String>)),
    );
    expect(item.enabled, isFalse, reason: '超限要在点之前就说清楚，不是点下去才报错');
    expect(tester.takeException(), isNull);
  });

  testWidgets('第 4 层仍允许新建子分组（上限的边界内侧）', (tester) async {
    var parentId = (await repo.allDecks()).first.id;
    for (var level = 2; level <= 4; level++) {
      parentId = (await repo.createDeck('K$level', parentId: parentId)).id;
    }
    await mount(tester, const RootShell(), const Size(1280, 800));
    await tester.ensureVisible(menuOf('K4'));
    await tester.pumpAndSettle();
    await tester.tap(menuOf('K4'));
    await tester.pumpAndSettle();
    expect(find.text('已达 5 层'), findsNothing);
    expect(
        tester
            .widget<PopupMenuItem<String>>(find.ancestor(
                of: find.text('新建子分组'),
                matching: find.byType(PopupMenuItem<String>)))
            .enabled,
        isTrue);
  });

  testWidgets('删除父分组前如实报出子分组与卡片数量', (tester) async {
    final root = await repo.createDeck('待删根');
    final child = await repo.createDeck('待删子', parentId: root.id);
    await repo.createBasicNote(deckId: child.id, front: 'q', back: 'a');

    await mount(tester, const RootShell(), const Size(1280, 800));
    await tester.tap(menuOf('待删根'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('及其 1 个子分组、1 张卡片'), findsOneWidget,
        reason: '删除范围必须写明，不能只说"将被删除"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('同父重名被拒时给出可读提示而不是崩溃', (tester) async {
    await repo.createDeck('重名组');
    await mount(tester, const RootShell(), const Size(1280, 800));

    await tester.tap(menuOf('重名组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '默认牌组');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('顶层已有名为「默认牌组」的分组'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情页面包屑显示父路径且可点回上层', (tester) async {
    final root = await repo.createDeck('大模型');
    final child = await repo.createDeck('深度学习', parentId: root.id);

    await mount(
      tester,
      DeckDetailScreen(deckId: child.id, deckName: child.name),
      const Size(1280, 800),
    );
    expect(find.text('大模型'), findsOneWidget, reason: '面包屑应显示父组');
    expect(find.text('›'), findsOneWidget);

    await tester.tap(find.text('大模型'));
    await tester.pumpAndSettle();
    // 点父组后进入父组详情：它自己是顶层，不该再有面包屑箭头。
    expect(find.text('›'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶层分组不显示面包屑', (tester) async {
    final root = (await repo.allDecks()).first;
    await mount(
      tester,
      DeckDetailScreen(deckId: root.id, deckName: root.name),
      const Size(1280, 800),
    );
    expect(find.text('›'), findsNothing);
  });

  testWidgets('详情页删除确认如实报数，且不谎称"不可撤销"', (tester) async {
    final root = await repo.createDeck('详情待删根');
    final child = await repo.createDeck('详情待删子', parentId: root.id);
    await repo.createBasicNote(deckId: child.id, front: 'q', back: 'a');

    await mount(
      tester,
      DeckDetailScreen(deckId: root.id, deckName: root.name),
      const Size(1280, 800),
    );
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除分组'));
    await tester.pumpAndSettle();

    expect(find.textContaining('及其 1 个子分组、1 张卡片'), findsOneWidget,
        reason: 'P0-10 的影响面在详情页也必须给，不能只在首页有');
    expect(find.textContaining('此操作不可撤销'), findsNothing,
        reason: '软删进回收站是可恢复的，说"不可撤销"是假话');
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情页菜单有"新建子分组/移动到…"，建完真的挂在当前组下', (tester) async {
    final root = await repo.createDeck('详情父组');

    await mount(
      tester,
      DeckDetailScreen(deckId: root.id, deckName: root.name),
      const Size(1280, 800),
    );
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('新建子分组'), findsOneWidget, reason: 'P0-9 要求详情页也有入口');
    expect(find.text('移动到…'), findsOneWidget);

    await tester.tap(find.text('新建子分组'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '详情子组');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    final decks = await repo.allDecks();
    expect(decks.firstWhere((d) => d.name == '详情子组').parentId, root.id,
        reason: '入口必须真的落到这一组下面，而不是建到顶层');
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情页在第 5 层也把"新建子分组"置灰', (tester) async {
    var parentId = (await repo.allDecks()).first.id;
    for (var level = 2; level <= 5; level++) {
      parentId = (await repo.createDeck('D$level', parentId: parentId)).id;
    }

    await mount(
      tester,
      DeckDetailScreen(deckId: parentId, deckName: 'D5'),
      const Size(1280, 800),
    );
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('已达 5 层'), findsOneWidget);
    expect(
        tester
            .widget<PopupMenuItem<String>>(find.ancestor(
                of: find.text('新建子分组'),
                matching: find.byType(PopupMenuItem<String>)))
            .enabled,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动到…：候选排除自己与后代，移动后层级真的变了', (tester) async {
    final a = await repo.createDeck('父A');
    final aChild = await repo.createDeck('子A', parentId: a.id);
    await repo.createDeck('父B');

    await mount(tester, const RootShell(), const Size(1280, 800));
    await tester.ensureVisible(menuOf('子A'));
    await tester.pumpAndSettle();
    await tester.tap(menuOf('子A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动到…'));
    await tester.pumpAndSettle();

    // 限定在对话框内找：背景首页上也挂着「子A」这张卡片。
    Finder inDialog(String text) => find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(text),
        );

    expect(inDialog('顶层（不作为子分组）'), findsOneWidget);
    expect(inDialog('父B'), findsOneWidget);
    expect(inDialog('子A'), findsNothing,
        reason: '不能把自己或自己的后代当目标（会成环）');

    await tester.tap(inDialog('父B'));
    await tester.pumpAndSettle();

    final reloaded = CollectionRepo(db);
    expect((await reloaded.deckPathNames(aChild.id)), ['父B', '子A']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('今日面板不因层级重复计数（父与子只能算一次）', (tester) async {
    // setUp 已有 4 张卡（默认组 3 + 英语单词 1）。再建一棵 3 层的树放 3 张。
    final root = await repo.createDeck('大模型');
    final mid = await repo.createDeck('深度学习', parentId: root.id);
    final leaf = await repo.createDeck('面试题', parentId: mid.id);
    await repo.createBasicNote(deckId: root.id, front: 'r1', back: 'x');
    await repo.createBasicNote(deckId: mid.id, front: 'm1', back: 'x');
    await repo.createBasicNote(deckId: leaf.id, front: 'l1', back: 'x');

    await mount(tester, const RootShell(), const Size(1280, 800));
    // 逐分组累加会得到 10（父+子重复），只累加根才等于真实的 7。
    expect(find.textContaining('已学 0/7 张 · 新卡 7'), findsOneWidget);
    expect(find.text('7'), findsOneWidget, reason: '待学大数字');
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部导航「添加」可打开弹层并保存', (tester) async {
    await mount(tester, const RootShell(), const Size(390, 844));
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('添加卡片'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), '纸上得来终觉浅');
    await tester.enterText(find.byType(TextField).at(1), '绝知此事要躬行');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final cards = await (db.select(db.cards)).get();
    expect(cards.length, 5, reason: '原有 4 张（3 默认组 + 1 英语组）+ 新增 1 张');
    expect(tester.takeException(), isNull);
  });

  testWidgets('从分组页底部添加，卡片落在该组而非第一个组', (tester) async {
    // 回归：showAddCardSheet 曾经永远预选 decks.first，
    // 在"英语单词"里点添加会把卡建到"默认牌组"。
    final decks = await repo.allDecks();
    final target = decks.firstWhere((d) => d.name == '英语单词');

    await mount(
      tester,
      DeckDetailScreen(deckId: target.id, deckName: target.name),
      const Size(390, 844),
    );
    await tester.tap(find.text('添加卡片到本组'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'serendipity');
    await tester.enterText(find.byType(TextField).at(1), 'n. 意外发现美好');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final cards = await (db.select(db.cards)
          ..where((c) => c.deckId.equals(target.id)))
        .get();
    expect(cards.length, 2, reason: '该组原有 1 张 + 新增 1 张');
    // 在 Dart 侧过滤，避免 import drift 后它的 Column 与 material 的 Column 撞名。
    final allNotes = await db.select(db.notes).get();
    final notes =
        allNotes.where((n) => n.fields.contains('serendipity')).toList();
    expect(notes, hasLength(1));
    expect(cards.any((c) => c.noteId == notes.first.id), isTrue,
        reason: '新卡片确实挂在目标分组下，而不是第一个分组');
    expect(tester.takeException(), isNull);
  });
}
