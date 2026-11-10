import 'dart:convert';

import 'package:drift/drift.dart';

import '../fsrs/fsrs.dart';
import '../data/database.dart';
import 'cloze_parser.dart';
import 'deck_tree.dart';

export 'deck_tree.dart';

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

  // ---------------------------------------------------------------------------
  // 同步设置（只存本机）
  // ---------------------------------------------------------------------------
  //
  // 存在 collection_configs，而该表**不在同步 payload 里**
  // （sync_client._collectLocalChanges 只收集 deck/note/card），
  // 所以服务器地址与密钥不会上传到同步服务端。

  /// 同步服务器地址。
  String syncServerUrl = 'http://127.0.0.1:8787';

  /// 上次使用的账号。
  String syncUsername = '';

  /// 上次使用的密钥（本机明文，与卡片数据同一保护级别）。
  String syncSecret = '';

  /// 上次登录拿到的会话 token（重启后据此免登录直接同步）。
  String syncToken = '';

  /// token 对应的账号 id。
  String syncAccountId = '';

  /// 上次同步游标（下次只拉增量，不必全量重拉）。
  int syncCursor = 0;

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

    // 同步设置：缺失则保留当前默认值。
    final url = map['sync_server_url'];
    final user = map['sync_username'];
    final secret = map['sync_secret'];
    final cursor = int.tryParse(map['sync_cursor'] ?? '');
    if (url != null && url.trim().isNotEmpty) syncServerUrl = url;
    if (user != null) syncUsername = user;
    if (secret != null) syncSecret = secret;
    if (cursor != null) syncCursor = cursor;
    syncToken = map['sync_token'] ?? '';
    syncAccountId = map['sync_account_id'] ?? '';
  }

  /// 持久化当前设置项到集合配置。
  Future<void> saveSettings() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _upsertConfig('desired_retention', desiredRetention.toStringAsFixed(2), now);
    await _upsertConfig('new_cards_per_day', '$newCardsPerDay', now);
    await _upsertConfig('max_reviews_per_day', '$maxReviewsPerDay', now);
  }

  /// 单独持久化同步设置。
  ///
  /// 不与 [saveSettings] 合并：学习设置页滑杆结束时也会写库，若把同步字段
  /// 一起写，可能用内存里的旧值覆盖掉刚在同步页存下的新值。
  Future<void> saveSyncSettings() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _upsertConfig('sync_server_url', syncServerUrl, now);
    await _upsertConfig('sync_username', syncUsername, now);
    await _upsertConfig('sync_secret', syncSecret, now);
    await _upsertConfig('sync_cursor', '$syncCursor', now);
    await _upsertConfig('sync_token', syncToken, now);
    await _upsertConfig('sync_account_id', syncAccountId, now);
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
  // 牌组（最多 kMaxDeckDepth 层的树）
  // ---------------------------------------------------------------------------

  /// 未删除的全部分组（原始顺序，供树计算与校验用）。
  Future<List<Deck>> liveDecks() =>
      (db.select(db.decks)..where((t) => t.deleted.equals(false))).get();

  /// 全部牌组，按**树的前序**（父在前、同级按名）稳定排序。
  Future<List<Deck>> allDecks() async =>
      forestPreOrder(await liveDecks());

  /// 首页用的森林：每个节点带深度与**子树聚合**计数。
  Future<List<DeckNode>> deckTree({DateTime? now}) async =>
      buildTree(await liveDecks(), await _perDeckCounts(now));

  /// 新建分组。
  ///
  /// [parentId] 为 null 表示顶层。写入前校验两件事：
  ///  * 深度不超过 [kMaxDeckDepth]；
  ///  * 同一父下不重名（不同父下允许同名，例如 `A::算法` 与 `B::算法`）。
  ///
  /// [reuseOnConflict] 为 true 时（导入路径）同父重名**复用**已有分组而不是报错——
  /// 导入 320 行时弹 30 次冲突提示会毁掉整个流程；手动新建走默认 false。
  Future<Deck> createDeck(String name,
      {String? parentId, bool reuseOnConflict = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('分组名不能为空');

    final decks = await liveDecks();
    final parentDepth = parentId == null ? 0 : depthOf(decks, parentId);
    if (parentDepth + 1 > kMaxDeckDepth) {
      throw DeckDepthException(parentDepth);
    }

    final parentName = parentId == null ? null : byId(decks, parentId)?.name;
    for (final d in decks) {
      if ((d.parentId ?? '') == (parentId ?? '') && d.name == trimmed) {
        if (reuseOnConflict) return d;
        throw DeckNameConflictException(trimmed, parentName: parentName);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final deck = DecksCompanion.insert(
      id: newId(),
      name: trimmed,
      parentId: Value(parentId),
      version: now,
    );
    await db.into(db.decks).insert(deck);
    return (db.select(db.decks)..where((t) => t.id.equals(deck.id.value))).getSingle();
  }

  /// 重命名分组（同父下不得与兄弟重名）。
  Future<void> renameDeck(String deckId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('分组名不能为空');

    final decks = await liveDecks();
    final self = byId(decks, deckId);
    if (self == null) return;

    for (final d in decks) {
      if (d.id != deckId &&
          (d.parentId ?? '') == (self.parentId ?? '') &&
          d.name == trimmed) {
        throw DeckNameConflictException(trimmed,
            parentName: self.parentId == null
                ? null
                : byId(decks, self.parentId!)?.name);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.decks)..where((t) => t.id.equals(deckId))).write(
      DecksCompanion(name: Value(trimmed), version: Value(now)),
    );
  }

  /// 把分组移动到另一个父下（[newParentId] 为 null 表示移到顶层）。
  ///
  /// 三道校验：不成环、整棵子树搬过去后最深点不超 [kMaxDeckDepth]、目标父下不重名。
  Future<void> moveDeck(String deckId, String? newParentId) async {
    final decks = await liveDecks();
    final self = byId(decks, deckId);
    if (self == null) return;
    if ((self.parentId ?? '') == (newParentId ?? '')) return; // 没变化

    if (newParentId != null &&
        (newParentId == deckId ||
            descendantIds(decks, deckId).contains(newParentId))) {
      throw DeckCycleException(self.name, byId(decks, newParentId)?.name ?? '');
    }

    final newParentDepth = newParentId == null ? 0 : depthOf(decks, newParentId);
    final subDepth = maxSubtreeDepth(decks, deckId);
    if (newParentDepth + subDepth > kMaxDeckDepth) {
      throw DeckDepthException(newParentDepth + subDepth - 1);
    }

    for (final d in decks) {
      if (d.id != deckId &&
          (d.parentId ?? '') == (newParentId ?? '') &&
          d.name == self.name) {
        throw DeckNameConflictException(self.name,
            parentName: newParentId == null
                ? null
                : byId(decks, newParentId)?.name);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.decks)..where((t) => t.id.equals(deckId)))
        .write(DecksCompanion(parentId: Value(newParentId), version: Value(now)));
  }

  /// 删除分组：**级联**软删整棵子树，以及子树内的全部卡片。
  ///
  /// 不级联就会留下"父已删、子还活着"的孤儿分组。笔记本身保留（软删不物理清除，
  /// 便于同步传播与误删恢复）。返回影响面，供 UI 如实提示。
  Future<DeckDeleteReport> deleteDeck(String deckId) async {
    final decks = await liveDecks();
    final ids = subtreeIds(decks, deckId);
    final cards = await (db.select(db.cards)
          ..where((c) => c.deleted.equals(false) & c.deckId.isIn(ids)))
        .get();

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.decks)..where((t) => t.id.isIn(ids)))
        .write(DecksCompanion(deleted: const Value(true), version: Value(now)));
    if (cards.isNotEmpty) {
      await (db.update(db.cards)..where((c) => c.id.isIn(cards.map((c) => c.id).toSet())))
          .write(CardsCompanion(deleted: const Value(true), version: Value(now)));
    }

    return DeckDeleteReport(
      deckName: byId(decks, deckId)?.name ?? '',
      decksDeleted: ids.length,
      cardsDeleted: cards.length,
    );
  }

  /// 某分组的完整路径（根 -> 自身），用于面包屑与导入提示。
  Future<List<String>> deckPathNames(String deckId) async =>
      (chainOf(await liveDecks(), deckId)).map((d) => d.name).toList();

  /// 某分组从根到自身的分组对象链（面包屑要能点，所以需要 id）。
  Future<List<Deck>> deckChain(String deckId) async =>
      chainOf(await liveDecks(), deckId);

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

  /// 编辑卡片内容:更新其笔记的字段与标签。
  ///
  /// [fields] 为该笔记的字段数组(基本=2项,完形填空=1项);
  /// [tags] 若非 null 则覆盖标签。
  Future<void> updateNoteContent({
    required String noteId,
    required List<String> fields,
    List<String>? tags,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final encoded = jsonEncode(fields);
    await (db.update(db.notes)..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        fields: Value(encoded),
        tags: tags != null ? Value(tags.join(' ')) : const Value.absent(),
        version: Value(now),
      ),
    );
  }

  /// 移动卡片到另一牌组(改卡片所属分组)。
  Future<void> moveCard({required String cardId, required String toDeckId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.cards)..where((c) => c.id.equals(cardId)))
        .write(CardsCompanion(deckId: Value(toDeckId), version: Value(now)));
  }

  /// 删除单张卡片(软删除)。
  Future<void> deleteCard(String cardId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.cards)..where((c) => c.id.equals(cardId)))
        .write(CardsCompanion(deleted: const Value(true), version: Value(now)));
  }

  /// 取（或创建）完形填空笔记类型。
  Future<NoteType> _clozeNoteType() async {
    // 用 .get() 而非 getSingleOrNull(),避免多行时抛 "Too many elements"。
    final clozeTypes = await (db.select(db.noteTypes)
          ..where((t) => t.deleted.equals(false) & t.isCloze.equals(true)))
        .get();
    if (clozeTypes.isNotEmpty) return clozeTypes.first;
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

  /// 取默认笔记类型(用于"基本"卡片)。
  ///
  /// 必须用 `.get()` 而非 `.getSingle()`:笔记类型可能有多个(基本 + 完形填空),
  /// `.getSingle()` 在多行时会抛 "Too many elements" 导致建卡崩溃。
  /// 优先取非完形填空的类型,否则取第一个。
  Future<NoteType> _defaultNoteType() async {
    final types =
        await (db.select(db.noteTypes)..where((x) => x.deleted.equals(false))).get();
    if (types.isEmpty) {
      throw StateError('没有可用的笔记类型(应由 seedDefaults 创建)');
    }
    for (final t in types) {
      if (!t.isCloze) return t;
    }
    return types.first;
  }

  // ---------------------------------------------------------------------------
  // 复习队列
  // ---------------------------------------------------------------------------

  /// 取某牌组今日待复习/待学习卡片。
  ///
  /// **子树聚合**：点父分组就是把整棵子树的到期卡一起背（Anki 语义）。
  /// 每日额度也按子树整体计，不会因为分组拆得多就放大上限。
  Future<List<Card>> dueCards(String deckId, {DateTime? now}) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final todayStart = _startOfDayMs(now ?? DateTime.now());
    final ids = subtreeIds(await liveDecks(), deckId);

    // 到期：queue 为 learning/review/relearning 且 due<=now，或新卡 due<=今日上限。
    final due = await (db.select(db.cards)
          ..where((c) =>
              c.deleted.equals(false) &
              c.deckId.isIn(ids) &
              c.queue.isBiggerOrEqualValue(0) &
              c.due.isBiggerOrEqualValue(0) &
              c.due.isSmallerOrEqualValue(nowMs))
          ..orderBy([(c) => OrderingTerm(expression: c.queue)]))
        .get();

    // 新卡今日数量限制
    final reviewedToday = await _newCardsIntroducedToday(ids, todayStart);
    var newQuota = newCardsPerDay - reviewedToday;

    // 复习卡今日数量限制：非新卡（学习/复习/重学）按 maxReviewsPerDay 封顶，
    // 已答的先扣掉。
    final reviewsDoneToday = await _reviewsDoneToday(ids, todayStart);
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

  /// 今日已作答的非新卡数量（用于复习上限）。[ids] 为子树全部分组。
  Future<int> _reviewsDoneToday(Set<String> ids, int sinceMs) async {
    final logs = await (db.select(db.reviewLogs)..where((l) => l.undone.equals(false)))
        .get();
    if (logs.isEmpty) return 0;
    // 关联到本子树的卡片。
    final cardIds = (await (db.select(db.cards)
              ..where((c) => c.deckId.isIn(ids) & c.deleted.equals(false)))
            .get())
        .map((c) => c.id)
        .toSet();
    return logs
        .where((l) => cardIds.contains(l.cardId) && l.reviewedAt >= sinceMs)
        .length;
  }

  Future<int> _newCardsIntroducedToday(Set<String> ids, int sinceMs) async {
    final q = await (db.select(db.cards)
          ..where((c) =>
              c.deleted.equals(false) &
              c.deckId.isIn(ids) &
              c.queue.isBiggerOrEqualValue(0)))
        .get();
    // 新卡转学习的判据：reps>0 且首次复习在今日。
    return q.where((c) => c.reps > 0 && c.lastReview >= sinceMs && c.lastReview > 0).length;
  }

  /// 一次查询算出**每个分组自己**的计数（不聚合），供树/聚合复用，避免 N+1。
  Future<Map<String, DeckCounts>> _perDeckCounts(DateTime? now) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final cards =
        await (db.select(db.cards)..where((c) => c.deleted.equals(false))).get();
    final out = <String, DeckCounts>{};
    for (final c in cards) {
      var n = 0, l = 0, r = 0;
      if (c.queue == Queue.newCard) {
        n = 1;
      } else if (c.queue == Queue.learning || c.queue == Queue.relearning) {
        if (c.due <= nowMs) l = 1;
      } else if (c.queue == Queue.review) {
        if (c.due <= nowMs) r = 1;
      }
      final prev = out[c.deckId] ?? DeckCounts.zero;
      out[c.deckId] = DeckCounts(
        newCards: prev.newCards + n,
        learning: prev.learning + l,
        review: prev.review + r,
        totalCards: prev.totalCards + 1,
        // 非新卡即"已学过"；挂起卡也算学过（与旧口径一致）。
        studiedCards: prev.studiedCards + (c.queue == Queue.newCard ? 0 : 1),
      );
    }
    return out;
  }

  /// 某牌组今日统计（新/学习/到期）+ 总数/已学（供界面进度条与徽标）。
  ///
  /// 层级化后口径是**整棵子树**，每张卡只计一次（由 [subtreeCount] 累加）。
  ///
  /// - [total]（getter）: 今日待处理（新 + 到期学习/复习），即"待学习"数。
  /// - [totalCards]: 子树内卡片总数（Y）。
  /// - [studiedCards]: 已学过（非新卡）数量（X），用于"已学X/Y"与进度条。
  Future<DeckCounts> deckCounts(String deckId, {DateTime? now}) async {
    final decks = await liveDecks();
    final per = await _perDeckCounts(now);
    return subtreeCount(decks, per, deckId);
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

/// 删除分组的影响面（供 UI 如实提示"含 N 个子分组、M 张卡片"）。
class DeckDeleteReport {
  const DeckDeleteReport({
    required this.deckName,
    required this.decksDeleted,
    required this.cardsDeleted,
  });

  final String deckName;

  /// 被删分组数（**含自身**）。
  final int decksDeleted;
  final int cardsDeleted;

  /// 连带被删的子分组数（不含自身）。
  int get childDecksDeleted => decksDeleted - 1;
  bool get hasChildren => childDecksDeleted > 0;
}

/// JSON 字符串转义（避免手写引号问题）。
String _jsonStr(String s) => '"${s.replaceAll('"', r'\"')}"';
