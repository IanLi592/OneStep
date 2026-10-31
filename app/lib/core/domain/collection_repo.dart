import 'package:drift/drift.dart';

import '../fsrs/fsrs.dart';
import '../data/database.dart';
import 'cloze_parser.dart';

/// 评分档位常量（与 FSRS 1..4 对齐）。
class Rating {
  static const int again = 1;
  static const int hard = 2;
  static const int good = 3;
  static const int easy = 4;
}

/// 卡片队列状态常量。
class Queue {
  static const int newCard = 0;
  static const int learning = 1;
  static const int review = 2;
  static const int relearning = 3;
  static const int suspended = -1;
}

/// 集合仓库：封装牌组/笔记/卡片/复习的读写与调度逻辑。
class CollectionRepo {
  CollectionRepo(this.db, {Fsrs? fsrs}) : _fsrs = fsrs ?? Fsrs();

  final OnestepDb db;
  final Fsrs _fsrs;

  /// 期望记忆保持率（默认 0.9）。
  double desiredRetention = 0.9;

  /// 每日新卡上限。
  int newCardsPerDay = 20;

  /// 每日复习上限。
  int maxReviewsPerDay = 200;

  /// 从集合配置加载设置项（应用启动时调用，恢复上次的值）。
  Future<void> loadSettings() async {
    final rows = await db.select(db.collectionConfigs).get();
    final map = {for (final r in rows) r.key: r.value};
    final ret = double.tryParse(map['desired_retention'] ?? '');
    final newCap = int.tryParse(map['new_cards_per_day'] ?? '');
    final revCap = int.tryParse(map['max_reviews_per_day'] ?? '');
    if (ret != null) desiredRetention = ret.clamp(0.70, 0.97);
    if (newCap != null) newCardsPerDay = newCap.clamp(0, 100);
    if (revCap != null) maxReviewsPerDay = revCap.clamp(20, 500);
  }

  /// 持久化当前设置项到集合配置。
  Future<void> saveSettings() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _upsertConfig('desired_retention', desiredRetention.toStringAsFixed(2), now);
    await _upsertConfig('new_cards_per_day', '$newCardsPerDay', now);
    await _upsertConfig('max_reviews_per_day', '$maxReviewsPerDay', now);
  }

  Future<void> _upsertConfig(String key, String value, int version) async {
    final existing =
        await (db.select(db.collectionConfigs)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (existing == null) {
      await db.into(db.collectionConfigs)
          .insert(CollectionConfigsCompanion.insert(key: key, value: value));
    } else {
      await (db.update(db.collectionConfigs)..where((t) => t.key.equals(key)))
          .write(CollectionConfigsCompanion(value: Value(value), version: Value(version)));
    }
  }

  // ---------------------------------------------------------------------------
  // 牌组
  // ---------------------------------------------------------------------------

  Future<List<Deck>> allDecks() =>
      (db.select(db.decks)..where((t) => t.deleted.equals(false))).get();

  Future<Deck> createDeck(String name, {String? parentId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deck = DecksCompanion.insert(
      id: newId(),
      name: name,
      parentId: Value(parentId),
      version: now,
    );
    await db.into(db.decks).insert(deck);
    return (db.select(db.decks)..where((t) => t.id.equals(deck.id.value))).getSingle();
  }

  // ---------------------------------------------------------------------------
  // 笔记与卡片
  // ---------------------------------------------------------------------------

  /// 新建一条"基本"笔记（正面/背面），生成一张卡片。
  Future<Note> createBasicNote({
    required String deckId,
    required String front,
    required String back,
    List<String> tags = const [],
  }) async {
    final type = await _defaultNoteType();
    final now = DateTime.now().millisecondsSinceEpoch;
    final noteId = newId();
    await db.into(db.notes).insert(NotesCompanion.insert(
      id: noteId,
      noteTypeId: type.id,
      fields: '[${_jsonStr(front)}, ${_jsonStr(back)}]',
      tags: Value(tags.join(' ')),
      guid: newId(),
      version: now,
    ));
    // 生成一张卡片
    await _createCard(noteId: noteId, deckId: deckId, templateIndex: 0);
    return (db.select(db.notes)..where((t) => t.id.equals(noteId))).getSingle();
  }

  /// 新建一条完形填空(Cloze)笔记：按 `{{cN::...}}` 的不同序号各生成一张卡片。
  /// 返回生成的卡片数；文本无 cloze 时返回 0 且不建任何记录。
  Future<Note?> createClozeNote({
    required String deckId,
    required String text,
    List<String> tags = const [],
  }) async {
    final indices = ClozeParser.indices(text);
    if (indices.isEmpty) return null;

    final type = await _clozeNoteType();
    final now = DateTime.now().millisecondsSinceEpoch;
    final noteId = newId();
    await db.into(db.notes).insert(NotesCompanion.insert(
      id: noteId,
      noteTypeId: type.id,
      fields: '[${_jsonStr(text)}]',
      tags: Value(tags.join(' ')),
      guid: newId(),
      version: now,
    ));
    // 每个 cloze 序号一张卡片。
    for (var i = 0; i < indices.length; i++) {
      await _createCard(noteId: noteId, deckId: deckId, templateIndex: i);
    }
    return (db.select(db.notes)..where((t) => t.id.equals(noteId))).getSingle();
  }

  /// 取（或创建）完形填空笔记类型。
  Future<NoteType> _clozeNoteType() async {
    final existing = await (db.select(db.noteTypes)
          ..where((t) => t.deleted.equals(false) & t.isCloze.equals(true)))
        .getSingleOrNull();
    if (existing != null) return existing;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId();
    await db.into(db.noteTypes).insert(NoteTypesCompanion.insert(
      id: id,
      name: '完形填空',
      fields: '["文本"]',
      templates: '[{"name":"Cloze","qfmt":"{{cloze:文本}}","afmt":"{{cloze:文本}}"}]',
      isCloze: const Value(true),
      version: now,
    ));
    return (db.select(db.noteTypes)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> _createCard({
    required String noteId,
    required String deckId,
    required int templateIndex,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.cards).insert(CardsCompanion.insert(
      id: newId(),
      noteId: noteId,
      deckId: deckId,
      templateIndex: Value(templateIndex),
      queue: const Value(Queue.newCard),
      due: const Value(0),
      version: now,
    ));
  }

  Future<NoteType> _defaultNoteType() async {
    final t = await (db.select(db.noteTypes)..where((x) => x.deleted.equals(false))).getSingle();
    return t;
  }

  // ---------------------------------------------------------------------------
  // 复习队列
  // ---------------------------------------------------------------------------

  /// 取某牌组今日待复习/待学习卡片（学习中优先，再复习，再新卡，按 due 排序）。
  Future<List<Card>> dueCards(String deckId, {DateTime? now}) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final todayStart = _startOfDayMs(now ?? DateTime.now());

    // 到期：queue 为 learning/review/relearning 且 due<=now，或新卡 due<=今日上限。
    final due = await (db.select(db.cards)
          ..where((c) =>
              c.deleted.equals(false) &
              c.deckId.equals(deckId) &
              c.queue.isBiggerOrEqualValue(0) &
              c.due.isBiggerOrEqualValue(0) &
              c.due.isSmallerOrEqualValue(nowMs))
          ..orderBy([(c) => OrderingTerm(expression: c.queue)]))
        .get();

    // 新卡今日数量限制
    final reviewedToday = await _newCardsIntroducedToday(deckId, todayStart);
    var newQuota = newCardsPerDay - reviewedToday;

    // 复习卡今日数量限制：非新卡（学习/复习/重学）按 maxReviewsPerDay 封顶，
    // 已答的先扣掉。
    final reviewsDoneToday = await _reviewsDoneToday(deckId, todayStart);
    var reviewQuota = maxReviewsPerDay - reviewsDoneToday;

    final result = <Card>[];
    for (final card in due) {
      if (card.queue == Queue.newCard) {
        if (newQuota <= 0) continue;
        newQuota--;
      } else {
        // 学习/复习/重学卡占复习额度。
        if (reviewQuota <= 0) continue;
        reviewQuota--;
      }
      result.add(card);
    }
    return result;
  }

  /// 今日已作答的非新卡数量（用于复习上限）。
  Future<int> _reviewsDoneToday(String deckId, int sinceMs) async {
    final logs = await (db.select(db.reviewLogs)..where((l) => l.undone.equals(false)))
        .get();
    if (logs.isEmpty) return 0;
    // 关联到本牌组的卡片。
    final cardIds = (await (db.select(db.cards)
              ..where((c) => c.deckId.equals(deckId) & c.deleted.equals(false)))
            .get())
        .map((c) => c.id)
        .toSet();
    return logs
        .where((l) => cardIds.contains(l.cardId) && l.reviewedAt >= sinceMs)
        .length;
  }

  Future<int> _newCardsIntroducedToday(String deckId, int sinceMs) async {
    final q = await (db.select(db.cards)
          ..where((c) =>
              c.deleted.equals(false) &
              c.deckId.equals(deckId) &
              c.queue.isBiggerOrEqualValue(0)))
        .get();
    // 新卡转学习的判据：reps>0 且首次复习在今日。
    return q.where((c) => c.reps > 0 && c.lastReview >= sinceMs && c.lastReview > 0).length;
  }

  /// 某牌组今日统计（新/学习/到期）。
  Future<DeckCounts> deckCounts(String deckId, {DateTime? now}) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final all = await (db.select(db.cards)
          ..where((c) => c.deleted.equals(false) & c.deckId.equals(deckId)))
        .get();
    var newCount = 0, learning = 0, review = 0;
    for (final c in all) {
      if (c.queue == Queue.newCard) {
        newCount++;
      } else if (c.queue == Queue.learning || c.queue == Queue.relearning) {
        if (c.due <= nowMs) learning++;
      } else if (c.queue == Queue.review) {
        if (c.due <= nowMs) review++;
      }
    }
    return DeckCounts(newCards: newCount, learning: learning, review: review);
  }

  // ---------------------------------------------------------------------------
  // 作答
  // ---------------------------------------------------------------------------

  /// 计算某卡片在四档评分下的结果（用于展示间隔预览）。
  NextStates previewCard(Card card) {
    final state = _stateOf(card);
    final elapsed = _elapsedDays(card);
    return _fsrs.nextStates(state, desiredRetention, elapsed);
  }

  /// 应用一次作答：更新卡片调度状态、写复习日志。返回新的卡片行。
  Future<Card> answerCard(Card card, int rating, {int takenMs = 0}) async {
    final state = _stateOf(card);
    final elapsed = _elapsedDays(card);
    final before = _fsrs.nextStates(state, desiredRetention, elapsed).forRating(rating);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final intervalDays = before.interval;
    // 间隔 <1 天按当天内处理；>=1 天对齐到次日起算。
    final dueMs = intervalDays < 1
        ? nowMs + (intervalDays * Duration.millisecondsPerDay).round()
        : _startOfDayMs(DateTime.now()) +
            Duration.millisecondsPerDay * intervalDays.floor();

    // 队列迁移：
    //  - 作答"忘记"：复习卡→重学；学习/新卡→学习中。
    //  - 其余评分：学习/重学卡毕业为复习卡；复习卡保持复习。
    final newQueue = rating == Rating.again
        ? (card.queue == Queue.review ? Queue.relearning : Queue.learning)
        : Queue.review;

    final updated = card.copyWith(
      queue: newQueue,
      due: dueMs,
      stability: before.memory.stability,
      difficulty: before.memory.difficulty,
      stabilityFast: before.memory.stabilityFast,
      reps: card.reps + 1,
      lapses: card.lapses + (rating == Rating.again ? 1 : 0),
      lastReview: nowMs,
      version: nowMs,
    );
    await (db.update(db.cards)..where((c) => c.id.equals(card.id))).write(CardsCompanion(
      queue: Value(newQueue),
      due: Value(dueMs),
      stability: Value(before.memory.stability),
      difficulty: Value(before.memory.difficulty),
      stabilityFast: Value(before.memory.stabilityFast),
      reps: Value(card.reps + 1),
      lapses: Value(card.lapses + (rating == Rating.again ? 1 : 0)),
      lastReview: Value(nowMs),
      version: Value(nowMs),
    ));

    await db.into(db.reviewLogs).insert(ReviewLogsCompanion.insert(
      id: newId(),
      cardId: card.id,
      rating: rating,
      reviewedAt: nowMs,
      takenMs: Value(takenMs),
      intervalBefore: Value(_currentIntervalDays(card)),
      intervalAfter: Value(intervalDays),
      version: nowMs,
    ));

    return updated;
  }

  /// 撤销上一次作答：把卡片**完整回滚**到作答前的快照，并标记对应日志为 undone。
  ///
  /// [card] 必须是作答前的卡片快照（调用方在作答前持有）。FSRS 状态本身是确定性的，
  /// 用快照回滚即可精确还原稳定度/难度/快速分量/复习次数/遗忘次数/队列/到期。
  Future<void> undoLastAnswer(Card card) async {
    final log = await (db.select(db.reviewLogs)
          ..where((l) => l.cardId.equals(card.id) & l.undone.equals(false))
          ..orderBy([(l) => OrderingTerm.desc(l.reviewedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (log == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.reviewLogs)..where((l) => l.id.equals(log.id)))
        .write(ReviewLogsCompanion(undone: const Value(true), version: Value(nowMs)));

    // 用作答前的完整快照回滚所有调度字段。
    await (db.update(db.cards)..where((c) => c.id.equals(card.id))).write(CardsCompanion(
      queue: Value(card.queue),
      due: Value(card.due),
      stability: Value(card.stability),
      difficulty: Value(card.difficulty),
      stabilityFast: Value(card.stabilityFast),
      reps: Value(card.reps),
      lapses: Value(card.lapses),
      lastReview: Value(card.lastReview),
      version: Value(nowMs),
    ));
  }

  // ---------------------------------------------------------------------------
  // 工具
  // ---------------------------------------------------------------------------

  MemoryState? _stateOf(Card card) {
    if (card.reps == 0 || card.stability <= 0) return null;
    return MemoryState(
      stability: card.stability,
      difficulty: card.difficulty,
      stabilityFast: card.stabilityFast > 0 ? card.stabilityFast : card.stability,
    );
  }

  double _elapsedDays(Card card) {
    if (card.lastReview == 0) return 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return ((nowMs - card.lastReview) / Duration.millisecondsPerDay).clamp(0, 36500);
  }

  double _currentIntervalDays(Card card) => card.stability;

  int _startOfDayMs(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.millisecondsSinceEpoch;
  }
}

/// 牌组今日计数。
class DeckCounts {
  const DeckCounts({required this.newCards, required this.learning, required this.review});
  final int newCards;
  final int learning;
  final int review;

  int get total => newCards + learning + review;
}

/// JSON 字符串转义（避免手写引号问题）。
String _jsonStr(String s) => '"${s.replaceAll('"', r'\"')}"';
