import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/browser_service.dart';
import 'package:onestep/core/domain/collection_repo.dart';

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

  test('createDeck 支持同名分组共存', () async {
    await repo.createDeck('重复分组');
    await repo.createDeck('重复分组');
    final decks = await repo.allDecks();
    expect(decks.where((d) => d.name == '重复分组').length, 2);
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
