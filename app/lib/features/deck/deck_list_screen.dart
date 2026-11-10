import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' show Deck;
import '../../core/domain/deck_tree.dart';
import '../../core/domain/providers.dart';
import '../../core/domain/stats_providers.dart';
import '../../core/domain/xlsx_import_service.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';
import '../card_edit/add_card_sheet.dart';
import '../review/review_screen.dart';
import '../../shared/quote_carousel.dart';
import 'deck_detail_screen.dart';

/// 首页（底部导航第一个 tab）：今日驾驶舱 + 分组列表。
///
/// 入口收敛：AppBar 只留「添加卡片」与「导入 Excel」两个常驻动作；
/// 统计/我的已收进底部导航，新建分组降为分节标题右侧的文字动作。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 被折叠的分组 id（记住的是"收起哪些"，默认全展开）。
  final Set<String> _collapsed = {};

  void _toggle(String id) => setState(() {
        if (!_collapsed.remove(id)) _collapsed.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);

    // 牌组变化时把最新待复习总数推给桌面小组件。
    ref.listen<AsyncValue<List<Deck>>>(decksProvider, (_, _) => _pushWidget());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('跬步'),
            Text(
              _todayLabel(),
              style:
                  TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: p.ink3),
            ),
          ],
        ),
        actions: [
          // 「添加」已移到下方底部导航，这里只留导入。
          IconButton(
            tooltip: '导入 Excel',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => _importXlsx(context),
          ),
          const SizedBox(width: InkTokens.s1),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: InkTokens.pageMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s8),
            children: [
              const _TodayPanel(),
              const QuoteCarousel(),
              InkSection(
                title: '我的分组',
                padding: const EdgeInsets.fromLTRB(
                    InkTokens.s1, InkTokens.s4, InkTokens.s1, InkTokens.s2),
                trailing: TextButton.icon(
                  onPressed: () => _showCreateDeckDialog(context),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('新建分组'),
                ),
              ),
              ref.watch(deckTreeProvider).when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: InkTokens.s8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    InkEmpty(title: '分组加载失败', hint: '$e', icon: Icons.error_outline),
                data: (tree) {
                  if (tree.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: InkTokens.s8),
                      child: InkEmpty(
                        title: '还没有分组',
                        hint: '先建一个分组，或从 Excel 批量导入卡片',
                        icon: Icons.folder_open_outlined,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final node in flattenVisible(tree, _collapsed))
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: InkTokens.s3,
                            // 每深一层缩进一档，层级关系一眼可见。
                            left: (node.depth - 1) * InkTokens.s4,
                          ),
                          child: _DeckCard(
                            node: node,
                            collapsed: _collapsed.contains(node.id),
                            onToggle: () => _toggle(node.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部副标题：今日日期与星期（不与轮播标语重复）。
  String _todayLabel() {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final n = DateTime.now();
    return '${n.month}月${n.day}日 · ${weekdays[n.weekday - 1]}';
  }

  /// 把最新待复习总数推送到桌面小组件。
  void _pushWidget() {
    // 异步推送，失败不影响主流程。
    ref.read(widgetUpdaterProvider).push();
  }

  /// 新增分组：弹窗输入名称，创建后刷新列表。
  Future<void> _showCreateDeckDialog(BuildContext context) async {
    final controller = TextEditingController();
    final repo = ref.read(repoProvider);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '分组名称',
            hintText: '例如：英语单词',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          InkButton(
            label: '创建',
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            expand: false,
            height: 44,
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await repo.createDeck(name);
      await refreshHome(ref);
      _pushWidget();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('已创建分组「$name」'),
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败：$e')));
      }
    }
  }

  /// 导入 Excel(.xlsx)：选文件 -> 解析 -> 按牌组建卡 -> 反馈。
  Future<void> _importXlsx(BuildContext context) async {
    List<PlatformFile> picked;
    try {
      picked =
          await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('打开文件选择器失败：$e')));
      }
      return;
    }
    if (picked.isEmpty) return; // 用户取消

    try {
      final pickedFile = picked.first;
      final bytes = await pickedFile.readAsBytes();
      final repo = ref.read(repoProvider);
      // 传文件名：闪记盒按叶子逐个导出，父路径只写在文件名里。
      final result = await XlsxImportService(repo)
          .importBytes(bytes, sourceFileName: pickedFile.name);

      if (result.aborted) {
        // D4：超 5 层整批中止，原样列出问题路径，让用户自己改文件而不是偷偷截断。
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('分组最多 $kMaxDeckDepth 层，以下路径超限，本次未导入：\n'
                  '${result.rejectedPaths.take(5).join('\n')}'
                  '${result.rejectedPaths.length > 5 ? '\n…共 ${result.rejectedPaths.length} 条' : ''}'),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return;
      }

      if (result.cardsCreated == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未从文件中解析到可导入的卡片')),
          );
        }
        return;
      }

      await refreshHome(ref);
      _pushWidget();
      if (context.mounted) {
        final depthHint = result.maxDepthReached > 1
            ? '，最深 ${result.maxDepthReached} 层'
            : '';
        final where = result.importedPaths.length == 1
            ? '\n归入：${result.importedPaths.first}'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入完成：${result.cardsCreated} 张卡片，'
              '新建 ${result.decksCreated} 个分组'
              '${result.decksReused > 0 ? '，复用 ${result.decksReused} 个' : ''}'
              '$depthHint$where',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }
}

/// 刷新首页所有派生计数。
///
/// 复习/编辑返回后必须整体刷一遍：今日面板、分组卡、进度环、连续打卡分别
/// 来自不同 provider，只刷其中一个就会出现"学了但数字不动"。
Future<void> refreshHome(WidgetRef ref) async {
  ref.invalidate(deckCountsProvider);
  ref.invalidate(deckTreeProvider);
  ref.invalidate(todayOverviewProvider);
  ref.invalidate(todayReviewCountProvider);
  ref.invalidate(studyStreakProvider);
  ref.invalidate(decksProvider);
}

/// 首页分组树（含子树聚合计数）。跟着 decksProvider 一起失效重算。
final deckTreeProvider = FutureProvider<List<DeckNode>>((ref) async {
  await ref.watch(decksProvider.future);
  return ref.watch(repoProvider).deckTree();
});

// ---------------------------------------------------------------------------
// 今日驾驶舱
// ---------------------------------------------------------------------------

/// 跨分组汇总出的今日面板数据。
class TodayOverview {
  const TodayOverview({
    required this.due,
    required this.studied,
    required this.totalCards,
    required this.newCards,
    required this.dueDeckId,
    required this.dueDeckName,
  });

  final int due;
  final int studied;
  final int totalCards;
  final int newCards;
  final String? dueDeckId;
  final String? dueDeckName;

  bool get hasWork => dueDeckId != null;
}

/// 首页今日总览：所有分组的待学/已学聚合 + 第一个有待学的分组。
///
/// 必须从**树的根节点**累加：deckCounts 是子树聚合口径，
/// 逐分组累加会把父子重复计数（实测 8 张卡会显示成 14 张）。
final todayOverviewProvider = FutureProvider<TodayOverview>((ref) async {
  await ref.watch(decksProvider.future);
  final repo = ref.watch(repoProvider);
  final tree = await repo.deckTree();
  var due = 0, studied = 0, total = 0, newC = 0;
  String? dueDeckId, dueDeckName;

  // 前序找第一个有待学的分组（父优先，与首页顺序一致）。
  String? pickedId, pickedName;
  void pick(List<DeckNode> nodes) {
    for (final n in nodes) {
      if (pickedId != null) return;
      if (n.counts.total > 0) {
        pickedId = n.id;
        pickedName = n.name;
        return;
      }
      pick(n.children);
    }
  }

  for (final root in tree) {
    due += root.counts.total;
    studied += root.counts.studiedCards;
    total += root.counts.totalCards;
    newC += root.counts.newCards;
  }
  pick(tree);
  dueDeckId = pickedId;
  dueDeckName = pickedName;

  return TodayOverview(
    due: due,
    studied: studied,
    totalCards: total,
    newCards: newC,
    dueDeckId: dueDeckId,
    dueDeckName: dueDeckName,
  );
});

class _TodayPanel extends ConsumerWidget {
  const _TodayPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = InkPalette.of(context);
    final overview = ref.watch(todayOverviewProvider);
    final todayDone = ref.watch(todayReviewCountProvider);
    final streak = ref.watch(studyStreakProvider);

    return overview.when(
      loading: () => const SizedBox(height: 168),
      error: (e, _) => InkCard(
        raise: false,
        child: Text('今日概览加载失败：$e', style: TextStyle(color: p.cinnabar)),
      ),
      data: (ov) {
        final done = todayDone.valueOrNull ?? 0;
        final remaining = ov.due;
        final sessionTotal = done + remaining;
        final ring = sessionTotal == 0 ? 0.0 : done / sessionTotal;

        return InkCard(
          // 面板本身不可点（"开始学习"是唯一入口），所以关掉按压阴影。
          raise: false,
          borderColor: p.primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(InkTokens.s5),
          child: Column(
            children: [
              Row(
                children: [
                  InkRing(
                    value: ring,
                    color: p.primary,
                    trackColor: p.sunken,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$done',
                            style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: p.ink1)),
                        Text('今日已学', style: TextStyle(fontSize: 10.5, color: p.ink3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: InkTokens.s5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$remaining',
                                style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700,
                                    height: 1.05,
                                    letterSpacing: 0.5,
                                    color: remaining > 0 ? p.cinnabar : p.pine)),
                            const SizedBox(width: InkTokens.s2),
                            Text('张待学',
                                style: TextStyle(fontSize: 14.5, color: p.ink2)),
                          ],
                        ),
                        const SizedBox(height: InkTokens.s1),
                        Text(
                          ov.totalCards == 0
                              ? '还没有卡片，点下方「添加」新建'
                              : '已学 ${ov.studied}/${ov.totalCards} 张 · 新卡 ${ov.newCards}',
                          style: TextStyle(fontSize: 12.5, color: p.ink3),
                        ),
                        if ((streak.valueOrNull ?? 0) > 0) ...[
                          const SizedBox(height: InkTokens.s2),
                          InkChip(
                            label: '连续打卡 ${streak.valueOrNull ?? 0} 天',
                            icon: Icons.local_fire_department,
                            color: p.cinnabar,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: InkTokens.s4),
              // 三态而非两态：库里一张卡都没有时，"今日已清空"是句假话。
              if (ov.hasWork)
                InkButton(
                  label: '开始学习',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _start(context, ref, ov),
                )
              else if (ov.totalCards == 0)
                InkButton(
                  label: '添加第一张卡片',
                  icon: Icons.add,
                  onPressed: () => showAddCardSheet(context),
                )
              else
                InkButton(
                  label: '今日已清空',
                  icon: Icons.check_rounded,
                  tone: InkTone.pale,
                  onPressed: null,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _start(
      BuildContext context, WidgetRef ref, TodayOverview ov) async {
    final id = ov.dueDeckId;
    if (id == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReviewScreen(deckId: id, deckName: ov.dueDeckName ?? ''),
    ));
    if (!context.mounted) return;
    await refreshHome(ref);
  }
}

// ---------------------------------------------------------------------------
// 分组卡
// ---------------------------------------------------------------------------

class _DeckCard extends ConsumerWidget {
  const _DeckCard({
    required this.node,
    required this.collapsed,
    required this.onToggle,
  });

  final DeckNode node;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = InkPalette.of(context);
    final counts = node.counts;
    final due = counts.total;
    final empty = counts.totalCards == 0;
    final hasChildren = node.children.isNotEmpty;

    return InkCard(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              DeckDetailScreen(deckId: node.id, deckName: node.name),
        ));
        if (!context.mounted) return;
        await refreshHome(ref);
      },
      child: Column(
        children: [
          Row(
            children: [
              // 折叠箭头：有子分组就常驻显示，不靠 hover 显形。
              SizedBox(
                width: hasChildren ? 26 : 0,
                child: hasChildren
                    ? IconButton(
                        tooltip: collapsed ? '展开子分组' : '收起子分组',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: Icon(
                          collapsed
                              ? Icons.expand_more
                              : Icons.expand_less,
                          color: p.ink2,
                        ),
                        onPressed: onToggle,
                      )
                    : null,
              ),
              // 封面：统一墨青淡染 + 首字（单强调色原则）。
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primaryPale,
                  borderRadius: BorderRadius.circular(InkTokens.rButton),
                  border: Border.all(
                      color: p.primary.withValues(alpha: 0.3), width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  node.name.isEmpty ? '?' : node.name.characters.first,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: p.primary),
                ),
              ),
              const SizedBox(width: InkTokens.s3),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (empty)
                      InkChip(label: '空分组', color: p.ink3, dense: true)
                    else if (due > 0)
                      InkChip(label: '$due 待学', color: p.cinnabar, dense: true)
                    else
                      InkChip(label: '已清空', color: p.pine, dense: true),
                  ],
                ),
              ),
              _DeckMenu(node: node),
            ],
          ),
          if (empty) ...[
            const SizedBox(height: InkTokens.s3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('还没有卡片，点进去添加或从 Excel 导入',
                  style: TextStyle(fontSize: 12, color: p.ink3)),
            ),
          ] else ...[
            const SizedBox(height: InkTokens.s3),
            InkStrokeBar(
              value: counts.progress,
              height: 8,
              color: p.primary,
              deepColor: p.primaryDeep,
            ),
            const SizedBox(height: InkTokens.s2),
            Row(
              children: [
                Text('已学 ${counts.studiedCards}/${counts.totalCards}',
                    style: TextStyle(fontSize: 12, color: p.ink3)),
                const Spacer(),
                Text('${(counts.progress * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.ink2)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 分组行的操作菜单：新建子分组 / 重命名 / 删除。
///
/// 到第 5 层时"新建子分组"置灰并写明原因，而不是点下去才报错。
class _DeckMenu extends ConsumerStatefulWidget {
  const _DeckMenu({required this.node});

  final DeckNode node;

  @override
  ConsumerState<_DeckMenu> createState() => _DeckMenuState();
}

class _DeckMenuState extends ConsumerState<_DeckMenu> {
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  Future<void> _createChild() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('在「${widget.node.name}」下新建子分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '子分组名称'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          InkButton(
            label: '创建',
            expand: false,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final repo = ref.read(repoProvider);
    try {
      await repo.createDeck(name, parentId: widget.node.id);
      await refreshHome(ref);
      _toast('已在「${widget.node.name}」下创建「$name」');
    } on DeckDepthException catch (e) {
      _toast(e.toString());
    } on DeckNameConflictException catch (e) {
      _toast(e.toString());
    } catch (e) {
      _toast('创建失败：$e');
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: widget.node.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分组名称'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          InkButton(
            label: '保存',
            expand: false,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == widget.node.name || !mounted) {
      return;
    }
    final repo = ref.read(repoProvider);
    try {
      await repo.renameDeck(widget.node.id, name);
      await refreshHome(ref);
      _toast('已重命名为「$name」');
    } on DeckNameConflictException catch (e) {
      _toast(e.toString());
    } catch (e) {
      _toast('重命名失败：$e');
    }
  }

  Future<void> _delete() async {
    final node = widget.node;
    final childCount = node.subtreeDeckCount - 1;
    final cardCount = node.counts.totalCards;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = InkPalette.of(ctx);
        final scope = childCount > 0
            ? '及其 $childCount 个子分组、$cardCount 张卡片'
            : '及其中 $cardCount 张卡片';
        return AlertDialog(
          title: Text('删除「${node.name}」？'),
          content: Text('将删除该分组$scope。删除后进入回收站，可恢复。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消')),
            InkButton(
              label: '删除',
              tone: InkTone.solid,
              color: p.cinnabar,
              deep: p.cinnabarDeep,
              expand: false,
              height: 44,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(repoProvider);
    final report = await repo.deleteDeck(node.id);
    await refreshHome(ref);
    if (!mounted) return;
    _toast('已删除「${report.deckName}」'
        '${report.childDecksDeleted > 0 ? '（含 ${report.childDecksDeleted} 个子分组）' : ''}'
        '，共 ${report.cardsDeleted} 张卡片');
  }

  /// 移动到别的父分组（或移到顶层）。
  Future<void> _move() async {
    const topSentinel = '__top__'; // showDialog 的 null 表示"取消"，故另设哨兵
    final repo = ref.read(repoProvider);
    final all = await repo.liveDecks();
    if (!mounted) return;
    // 自己和自己整棵子树都不能当目标，否则成环。
    final excluded = subtreeIds(all, widget.node.id);
    final candidates = all.where((d) => !excluded.contains(d.id)).toList();

    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('把「${widget.node.name}」移动到'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, topSentinel),
            child: const Text('顶层（不作为子分组）'),
          ),
          for (final d in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d.id),
              child: Text(d.name),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    try {
      await repo.moveDeck(
          widget.node.id, target == topSentinel ? null : target);
      await refreshHome(ref);
      _toast('已移动「${widget.node.name}」');
    } on DeckCycleException catch (e) {
      _toast(e.toString());
    } on DeckDepthException catch (e) {
      _toast(e.toString());
    } on DeckNameConflictException catch (e) {
      _toast(e.toString());
    } catch (e) {
      _toast('移动失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final canAdd = widget.node.canAddChild;
    return PopupMenuButton<String>(
      tooltip: '分组操作',
      icon: Icon(Icons.more_horiz, size: 20, color: p.ink2),
      onSelected: (v) => switch (v) {
        'child' => _createChild(),
        'rename' => _rename(),
        'move' => _move(),
        'delete' => _delete(),
        _ => null,
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'child',
          enabled: canAdd,
          child: Row(
            children: [
              const Text('新建子分组'),
              const Spacer(),
              if (!canAdd)
                Text('已达 $kMaxDeckDepth 层',
                    style: TextStyle(fontSize: 11.5, color: p.ink3)),
            ],
          ),
        ),
        const PopupMenuItem(value: 'rename', child: Text('重命名')),
        const PopupMenuItem(value: 'move', child: Text('移动到…')),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
  }
}
