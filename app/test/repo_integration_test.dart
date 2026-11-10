import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/browser_service.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:onestep/core/domain/widget_updater.dart';

/// 集成测试：用内存数据库跑通"建卡 → 复习队列 → 四档作答 → 撤销"闭环，
/// 验证 Drift 数据层与 FSRS 调度真正联动。
void main() {
  late OnestepDb db;
  late CollectionRepo repo;

  setUp(() async {
    db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    repo = CollectionRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('seedDefaults 建立默认牌组与笔记类型', () async {
    final decks = await repo.allDecks();
    expect(decks, hasLength(1));
    expect(decks.first.name, '默认牌组');
  });

  test('多分组/多笔记类型时 seedDefaults 不崩(回归:getSingleOrNull 多行崩溃)', () async {
    // 模拟导入 Excel 后的库:多个分组 + 多个笔记类型。
    await repo.createDeck('大模型');
    await repo.createDeck('英语');
    await repo.createClozeNote(deckId: (await repo.allDecks()).first.id, text: 'c{{c1::x}}');

    // 再次 seedDefaults 应安全跳过(不抛 "Too many elements")。
    await db.seedDefaults();

    final decks = await repo.allDecks();
    expect(decks.length, greaterThanOrEqualTo(3)); // 默认 + 大模型 + 英语

    // 多笔记类型时,建基本卡片也不崩。
    final deck = decks.first;
    await repo.createBasicNote(deckId: deck.id, front: 'q', back: 'a');
    final counts = await repo.deckCounts(deck.id);
    expect(counts.newCards, greaterThan(0));
  });

  test('createDeck 新增分组', () async {
    final before = await repo.allDecks();
    final deck = await repo.createDeck('英语单词');
    expect(deck.name, '英语单词');
    final after = await repo.allDecks();
    expect(after.length, before.length + 1);
    expect(after.any((d) => d.name == '英语单词'), isTrue);
  });

  test('同父重名：手动新建被拒，导入路径可复用', () async {
    await repo.createDeck('重复分组');
    // 手动新建走默认 reuseOnConflict=false，必须让用户知道冲突。
    await expectLater(
      repo.createDeck('重复分组'),
      throwsA(isA<DeckNameConflictException>()),
    );
    // 导入路径走 true，静默复用，不打断整批。
    final reused = await repo.createDeck('重复分组', reuseOnConflict: true);
    expect(reused.name, '重复分组');
    final decks = await repo.allDecks();
    expect(decks.where((d) => d.name == '重复分组').length, 1,
        reason: '复用不该产生第二个同名组');
  });

  test('不同父下允许同名分组共存', () async {
    final a = await repo.createDeck('A组');
    final b = await repo.createDeck('B组');
    final leaf1 = await repo.createDeck('算法', parentId: a.id);
    final leaf2 = await repo.createDeck('算法', parentId: b.id);
    expect(leaf1.id, isNot(leaf2.id));
    // 顶层同名仍然互不影响。本文件 setUp 只种子了「默认牌组」1 个组。
    expect((await repo.allDecks()).length, 5);
  });

  // ---------------------------------------------------------------------------
  // 分组层级（最多 5 层）
  // ---------------------------------------------------------------------------

  group('分组层级', () {
    test('深度边界：第 5 层可建，第 6 层被拒', () async {
      var parentId = (await repo.allDecks()).first.id; // 默认牌组 = 第 1 层
      for (var level = 2; level <= 5; level++) {
        final created = await repo.createDeck('L$level', parentId: parentId);
        expect(await repo.deckPathNames(created.id), hasLength(level));
        parentId = created.id;
      }
      await expectLater(
        repo.createDeck('L6', parentId: parentId),
        throwsA(isA<DeckDepthException>()),
      );
    });

    test('级联删除：删父组连带整棵子树与全部卡片', () async {
      final root = await repo.createDeck('根');
      final mid = await repo.createDeck('中', parentId: root.id);
      final leaf = await repo.createDeck('叶', parentId: mid.id);
      await repo.createBasicNote(deckId: root.id, front: 'r1', back: 'x');
      await repo.createBasicNote(deckId: mid.id, front: 'm1', back: 'x');
      await repo.createBasicNote(deckId: leaf.id, front: 'l1', back: 'x');

      final report = await repo.deleteDeck(root.id);
      expect(report.decksDeleted, 3);
      expect(report.childDecksDeleted, 2);
      expect(report.cardsDeleted, 3);

      final decks = await repo.allDecks();
      expect(decks.where((d) => d.name == '中'), isEmpty,
          reason: '子分组绝不能变成孤儿');
      expect((await repo.deckCounts(leaf.id)).totalCards, 0);
    });

    test('子树聚合计数：每张卡只算一次', () async {
      final root = await repo.createDeck('聚合根');
      final c1 = await repo.createDeck('子1', parentId: root.id);
      final c2 = await repo.createDeck('子2', parentId: root.id);
      await repo.createBasicNote(deckId: root.id, front: 'r', back: 'x');
      await repo.createBasicNote(deckId: c1.id, front: 'a', back: 'x');
      await repo.createBasicNote(deckId: c2.id, front: 'b', back: 'x');

      final rootCounts = await repo.deckCounts(root.id);
      expect(rootCounts.totalCards, 3);
      expect(rootCounts.newCards, 3);
      expect((await repo.deckCounts(c1.id)).totalCards, 1);

      final tree = await repo.deckTree();
      final node = tree.firstWhere((n) => n.id == root.id);
      expect(node.children, hasLength(2));
      expect(node.counts.totalCards, 3);
      expect(node.depth, 1);
      expect(node.children.first.depth, 2);
    });

    test('父分组复习队列包含子树到期卡', () async {
      final root = await repo.createDeck('复习根');
      final child = await repo.createDeck('复习子', parentId: root.id);
      await repo.createBasicNote(deckId: root.id, front: 'rq', back: 'x');
      await repo.createBasicNote(deckId: child.id, front: 'cq', back: 'x');
      expect(await repo.dueCards(root.id), hasLength(2));
      expect(await repo.dueCards(child.id), hasLength(1));
    });

    test('小组件待读数不因层级重复计数', () async {
      final root = await repo.createDeck('组件根');
      final child = await repo.createDeck('组件子', parentId: root.id);
      await repo.createBasicNote(deckId: root.id, front: 'r', back: 'x');
      await repo.createBasicNote(deckId: child.id, front: 'c', back: 'x');
      // 默认牌组 0 张 + 该子树 2 张 = 2（若按旧写法逐组相加会变成 4）。
      expect(await WidgetUpdater(repo).totalDue(), 2);
    });

    test('moveDeck：环检测与"整棵子树搬过去超深"都被拒', () async {
      final root = await repo.createDeck('移动根');
      final l2 = await repo.createDeck('M2', parentId: root.id);
      await repo.createDeck('M3', parentId: l2.id); // root 子树深 3

      await expectLater(repo.moveDeck(root.id, root.id),
          throwsA(isA<DeckCycleException>()));
      await expectLater(repo.moveDeck(root.id, l2.id),
          throwsA(isA<DeckCycleException>()),
          reason: '挂到自己的后代下会成环');

      // 另一棵树：X(1) -> X2(2) -> X3(3)，把深 3 的子树挂到 X3 下会到第 6 层。
      final x = await repo.createDeck('X');
      final x2 = await repo.createDeck('X2', parentId: x.id);
      final x3 = await repo.createDeck('X3', parentId: x2.id);
      await expectLater(repo.moveDeck(root.id, x3.id),
          throwsA(isA<DeckDepthException>()));

      // 合法移动：挂到 X2 下 -> 最深 2+3=5，刚好允许。
      await repo.moveDeck(root.id, x2.id);
      final moved = await repo.deckPathNames(l2.id);
      expect(moved, ['X', 'X2', '移动根', 'M2']);
    });

    test('孤儿分组按顶层呈现（同步期父还没到）', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: newId(),
            name: '孤儿',
            parentId: const Value('不存在的父id'),
            version: 1,
          ));
      final tree = await repo.deckTree();
      final node = tree.firstWhere((n) => n.name == '孤儿');
      expect(node.depth, 1, reason: '父不存在的分组必须可见可学，不能凭空消失');
    });

    test('同级按创建顺序排，改名不会让分组乱跳', () async {
      final first = await repo.createDeck('zzz先建');
      final second = await repo.createDeck('aaa后建');
      // 种子默认牌组最先建，故顺序为 [默认牌组, first, second]。
      final roots = await repo.allDecks();
      expect(roots.map((d) => d.id).take(3).toList(),
          [roots.first.id, first.id, second.id]);
      expect(roots[1].name, 'zzz先建', reason: '不是按名字码位排（否则 aaa 会提前）');

      await repo.renameDeck(first.id, '改名了');
      final after = await repo.allDecks();
      expect(after[1].id, first.id, reason: '改名不该改变位置');
    });
  });

  test('createDeck 建的分组可正常建卡与复习', () async {
    final deck = await repo.createDeck('测试组');
    await repo.createBasicNote(deckId: deck.id, front: 'q', back: 'a');
    final counts = await repo.deckCounts(deck.id);
    expect(counts.newCards, 1);
    final due = await repo.dueCards(deck.id);
    expect(due, hasLength(1));
  });

  test('createBasicNote 生成笔记与一张新卡', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');
    final counts = await repo.deckCounts(deck.id);
    expect(counts.newCards, 1);
    expect(counts.total, 1);
  });

  test('新卡出现在复习队列，作答后离开新卡队列', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');

    final due = await repo.dueCards(deck.id);
    expect(due, hasLength(1));
    final card = due.first;
    expect(card.queue, Queue.newCard);
    expect(card.reps, 0);

    // 以"良好"作答
    final updated = await repo.answerCard(card, Rating.good);
    expect(updated.reps, 1);
    expect(updated.queue, Queue.review);
    expect(updated.stability, greaterThan(0)); // FSRS 给出稳定度
    expect(updated.lastReview, greaterThan(0));

    // 新卡额度已用完，队列应清空
    final dueAfter = await repo.dueCards(deck.id);
    expect(dueAfter, isEmpty);
  });

  test('评分档次越高，稳定度/间隔越大', () async {
    final deck = (await repo.allDecks()).first;
    // 建 4 张卡，分别用 4 档作答，比较稳定度。
    for (var i = 0; i < 4; i++) {
      await repo.createBasicNote(deckId: deck.id, front: 'q$i', back: 'a$i');
    }
    final due = await repo.dueCards(deck.id);
    expect(due, hasLength(4));

    final results = <int, double>{};
    for (var i = 0; i < 4; i++) {
      final rating = i + 1;
      final updated = await repo.answerCard(due[i], rating);
      results[rating] = updated.stability;
    }
    expect(results[1]!, lessThan(results[2]!));
    expect(results[2]!, lessThan(results[3]!));
    expect(results[3]!, lessThan(results[4]!));
  });

  test('again 会增加 lapses 并回到学习中队列', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');
    final card = (await repo.dueCards(deck.id)).first;
    final updated = await repo.answerCard(card, Rating.again);
    expect(updated.lapses, 1);
    expect(updated.queue, Queue.learning);
  });

  test('写入复习日志，且撤销会标记 undone', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');
    final card = (await repo.dueCards(deck.id)).first;
    await repo.answerCard(card, Rating.good);

    final logs = await db.select(db.reviewLogs).get();
    expect(logs, hasLength(1));
    expect(logs.first.undone, isFalse);

    await repo.undoLastAnswer(card);
    final logsAfter = await db.select(db.reviewLogs).get();
    expect(logsAfter.first.undone, isTrue);
  });

  test('每张卡的 due 被设置到未来', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');
    final card = (await repo.dueCards(deck.id)).first;
    final updated = await repo.answerCard(card, Rating.easy);
    expect(updated.due, greaterThan(DateTime.now().millisecondsSinceEpoch));
  });

  test('previewCard 返回四档间隔且单调', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');
    final card = (await repo.dueCards(deck.id)).first;
    final preview = repo.previewCard(card);
    expect(preview.easy.interval, greaterThan(preview.good.interval));
    expect(preview.good.interval, greaterThan(preview.hard.interval));
    expect(preview.hard.interval, greaterThan(preview.again.interval));
  });

  test('撤销完整回滚卡片状态（稳定度/难度/遗忘次数/复习次数）', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好');
    final original = (await repo.dueCards(deck.id)).first;

    // 用"忘记"作答，产生非零稳定度与一次遗忘。
    await repo.answerCard(original, Rating.again);
    final afterAnswer = await (db.select(db.cards)..where((c) => c.id.equals(original.id))).getSingle();
    expect(afterAnswer.lapses, 1);
    expect(afterAnswer.reps, 1);
    expect(afterAnswer.stability, greaterThan(0));

    // 撤销后应回到作答前的完整状态。
    await repo.undoLastAnswer(original);
    final restored = await (db.select(db.cards)..where((c) => c.id.equals(original.id))).getSingle();
    expect(restored.lapses, original.lapses); // 遗忘次数回到 0
    expect(restored.reps, original.reps); // 复习次数回到 0
    expect(restored.stability, original.stability); // 稳定度回到 0
    expect(restored.difficulty, original.difficulty);
    expect(restored.queue, original.queue); // 队列回到新卡
  });

  test('每日复习上限生效：超过上限的复习卡不进入队列', () async {
    final deck = (await repo.allDecks()).first;
    // 建 4 张卡并全部以"良好"作答，使其成为复习卡（due 在未来）。
    for (var i = 0; i < 4; i++) {
      await repo.createBasicNote(deckId: deck.id, front: 'q$i', back: 'a$i');
    }
    var due = await repo.dueCards(deck.id);
    for (final c in due) {
      await repo.answerCard(c, Rating.good);
    }

    // 把到期时间改回现在，模拟它们再次到期。
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final allCards = await db.select(db.cards).get();
    for (final c in allCards) {
      await (db.update(db.cards)..where((x) => x.id.equals(c.id)))
          .write(CardsCompanion(due: Value(nowMs - 1000)));
    }

    // 设复习上限为 2，则队列最多 2 张（4 张都已复习过、额度耗尽 → 0 张非新卡）。
    repo.maxReviewsPerDay = 2;
    due = await repo.dueCards(deck.id);
    // 4 张卡今天都答过 1 次（reps>0），reviewsDoneToday=4 > 上限2 → 复习额度为负 → 无复习卡。
    expect(due.where((c) => c.queue == Queue.review).length, 0);
  });

  test('设置项持久化：saveSettings 后新 repo 能恢复', () async {
    final deck = (await repo.allDecks()).first;
    expect(deck, isNotNull);

    // 改设置并保存。
    repo.newCardsPerDay = 55;
    repo.maxReviewsPerDay = 123;
    repo.desiredRetention = 0.85;
    await repo.saveSettings();

    // 用同一个 db 造一个新 repo（模拟应用重启）。
    final repo2 = CollectionRepo(db);
    expect(repo2.newCardsPerDay, 20); // 初始默认
    await repo2.loadSettings();
    expect(repo2.newCardsPerDay, 55);
    expect(repo2.maxReviewsPerDay, 123);
    expect(repo2.desiredRetention, closeTo(0.85, 0.001));
  });

  test('同步设置持久化：地址/账号/密钥/游标 重启后仍在', () async {
    repo.syncServerUrl = 'http://172.31.32.1:8787';
    repo.syncUsername = 'ian';
    repo.syncSecret = 'my-secret';
    repo.syncCursor = 1793582677000;
    await repo.saveSyncSettings();

    // 用同一个 db 造新 repo（模拟应用重启）。
    final repo2 = CollectionRepo(db);
    expect(repo2.syncServerUrl, 'http://127.0.0.1:8787'); // 未加载前仍是默认值
    await repo2.loadSettings();
    expect(repo2.syncServerUrl, 'http://172.31.32.1:8787');
    expect(repo2.syncUsername, 'ian');
    expect(repo2.syncSecret, 'my-secret');
    expect(repo2.syncCursor, 1793582677000);
  });

  test('登录 token 持久化：重启后仍能沿用会话', () async {
    repo.syncToken = 'tok-abc';
    repo.syncAccountId = 'acct_1';
    await repo.saveSyncSettings();

    final repo2 = CollectionRepo(db);
    expect(repo2.syncToken, isEmpty); // 未加载前不该有
    await repo2.loadSettings();
    expect(repo2.syncToken, 'tok-abc');
    expect(repo2.syncAccountId, 'acct_1');
  });

  test('两条写入路径互不干扰：saveSettings 不会覆盖已存的同步地址', () async {
    repo.syncServerUrl = 'http://10.0.0.9:8787';
    await repo.saveSyncSettings();

    // 模拟设置页滑杆结束只写学习设置。
    repo.newCardsPerDay = 7;
    await repo.saveSettings();

    final repo2 = CollectionRepo(db);
    await repo2.loadSettings();
    expect(repo2.newCardsPerDay, 7);
    expect(repo2.syncServerUrl, 'http://10.0.0.9:8787');
  });

  // ---------------------------------------------------------------------------
  // 增删改查(分组 + 卡片)
  // ---------------------------------------------------------------------------

  test('renameDeck 重命名分组', () async {
    final deck = await repo.createDeck('旧名字');
    await repo.renameDeck(deck.id, '新名字');
    final decks = await repo.allDecks();
    final updated = decks.firstWhere((d) => d.id == deck.id);
    expect(updated.name, '新名字');
  });

  test('deleteDeck 软删除分组及其卡片', () async {
    final deck = await repo.createDeck('待删分组');
    await repo.createBasicNote(deckId: deck.id, front: 'q1', back: 'a1');
    final before = await repo.deckCounts(deck.id);
    expect(before.totalCards, 1);

    await repo.deleteDeck(deck.id);

    // 分组不再出现在列表。
    final decks = await repo.allDecks();
    expect(decks.any((d) => d.id == deck.id), isFalse);
    // 卡片也被级联删除(计数为0)。
    final after = await repo.deckCounts(deck.id);
    expect(after.totalCards, 0);
  });

  test('updateNoteContent 编辑正面/背面与标签', () async {
    final deck = (await repo.allDecks()).first;
    final note = await repo.createBasicNote(deckId: deck.id, front: '旧正面', back: '旧背面');
    await repo.updateNoteContent(
      noteId: note.id,
      fields: ['新正面', '新背面'],
      tags: ['alpha', 'beta'],
    );
    final items = await BrowserService(db).search(const CardQuery());
    final updated = items.firstWhere((i) => i.note.id == note.id);
    expect(updated.displayFront, '新正面');
    expect(updated.displayBack, '新背面');
    expect(updated.note.tags, 'alpha beta');
  });

  test('moveCard 移动卡片到另一分组', () async {
    final d1 = await repo.createDeck('分组A');
    final d2 = await repo.createDeck('分组B');
    final note = await repo.createBasicNote(deckId: d1.id, front: 'mq', back: 'ma');
    final card = (await (db.select(db.cards)..where((c) => c.noteId.equals(note.id))).getSingle());

    await repo.moveCard(cardId: card.id, toDeckId: d2.id);

    final aCounts = await repo.deckCounts(d1.id);
    final bCounts = await repo.deckCounts(d2.id);
    expect(aCounts.totalCards, 0);
    expect(bCounts.totalCards, 1);
  });

  test('deleteCard 软删除单卡', () async {
    final deck = (await repo.allDecks()).first;
    final note = await repo.createBasicNote(deckId: deck.id, front: 'del', back: 'x');
    final card = (await (db.select(db.cards)..where((c) => c.noteId.equals(note.id))).getSingle());
    expect((await repo.deckCounts(deck.id)).totalCards, greaterThan(0));

    await repo.deleteCard(card.id);

    expect((await repo.deckCounts(deck.id)).totalCards, 0);
  });
}
