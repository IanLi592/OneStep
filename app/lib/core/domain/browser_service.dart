import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';
import 'collection_repo.dart';

/// 卡片搜索的过滤条件。
class CardQuery {
  const CardQuery({
    this.deckId,
    this.tag,
    this.state,
    this.text,
  });

  final String? deckId;
  final String? tag;
  final CardState? state;
  final String? text;

  bool get isEmpty => deckId == null && tag == null && state == null && (text == null || text!.isEmpty);
}

/// 卡片状态过滤枚举。
enum CardState { newCard, learning, review, suspended }

/// 卡片浏览器搜索服务：按牌组/标签/状态/文本过滤，返回卡片及其笔记字段。
class BrowserService {
  BrowserService(this.db);

  final OnestepDb db;

  /// 执行搜索。返回匹配的卡片（附带其笔记字段，便于展示正面文本）。
  Future<List<BrowseItem>> search(CardQuery query, {int limit = 500}) async {
    // 先按卡片条件过滤。
    var cond = db.cards.deleted.equals(false);
    if (query.deckId != null) {
      cond = cond & db.cards.deckId.equals(query.deckId!);
    }
    if (query.state != null) {
      cond = cond & _stateCond(query.state!);
    }

    final cardRows = await (db.select(db.cards)
          ..where((c) => cond)
          ..limit(limit))
        .get();

    // 取相关笔记，支持 tag / text 过滤。
    final noteIds = cardRows.map((c) => c.noteId).toSet();
    final notes = <String, Note>{};
    if (noteIds.isNotEmpty) {
      final noteRows = await (db.select(db.notes)..where((n) => n.id.isIn(noteIds))).get();
      for (final n in noteRows) {
        notes[n.id] = n;
      }
    }

    final out = <BrowseItem>[];
    for (final card in cardRows) {
      final note = notes[card.noteId];
      if (note == null) continue;

      if (query.tag != null && query.tag!.isNotEmpty) {
        final tags = note.tags.split(RegExp(r'\s+'));
        if (!tags.contains(query.tag)) continue;
      }
      if (query.text != null && query.text!.isNotEmpty) {
        final q = query.text!.toLowerCase();
        final hay = '${note.fields} ${note.tags}'.toLowerCase();
        if (!hay.contains(q)) continue;
      }
      out.add(BrowseItem(card: card, note: note));
    }
    return out;
  }

  Expression<bool> _stateCond(CardState s) {
    switch (s) {
      case CardState.newCard:
        return db.cards.queue.equals(Queue.newCard);
      case CardState.learning:
        return db.cards.queue.equals(Queue.learning) |
            db.cards.queue.equals(Queue.relearning);
      case CardState.review:
        return db.cards.queue.equals(Queue.review);
      case CardState.suspended:
        return db.cards.queue.equals(Queue.suspended);
    }
  }

  /// 挂起 / 取消挂起一张卡片。
  Future<void> setSuspended(String cardId, bool suspended) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(CardsCompanion(
      queue: Value(suspended ? Queue.suspended : Queue.review),
      version: Value(now),
    ));
  }

  /// 删除卡片（软删除，便于同步传播）。
  Future<void> deleteCard(String cardId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.cards)..where((c) => c.id.equals(cardId)))
        .write(CardsCompanion(deleted: const Value(true), version: Value(now)));
  }

  /// 全部标签（去重、排序），供过滤下拉用。
  Future<List<String>> allTags() async {
    final notes = await db.select(db.notes).get();
    final set = <String>{};
    for (final n in notes) {
      set.addAll(n.tags.split(RegExp(r'\s+')).where((t) => t.isNotEmpty));
    }
    final list = set.toList()..sort();
    return list;
  }
}

/// 一条浏览结果：卡片 + 其笔记。
class BrowseItem {
  const BrowseItem({required this.card, required this.note});
  final Card card;
  final Note note;

  /// 展示用的正面文本（第一个字段，去掉 cloze 标记）。
  String get displayFront {
    final fields = _decode(note.fields);
    if (fields.isEmpty) return '';
    return _stripCloze(fields.first);
  }

  /// 展示用的背面文本（第二个字段；完形填空则为完整原文）。
  String get displayBack {
    final fields = _decode(note.fields);
    if (fields.length < 2) return _stripCloze(fields.isEmpty ? '' : fields.first);
    return _stripCloze(fields[1]);
  }

  /// 去掉 cloze 标记，显示完整内容。
  String _stripCloze(String s) {
    return s.replaceAllMapped(
      RegExp(r'\{\{c\d+::([^{}]*?)\}\}'),
      (Match m) {
        final body = m.group(1)!;
        return body.contains('::') ? body.split('::').last : body;
      },
    );
  }

  List<String> _decode(String json) {
    final inner = json.trim();
    if (!inner.startsWith('[') || !inner.endsWith(']')) return [inner];
    try {
      final decoded = jsonDecode(inner) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      final body = inner.substring(1, inner.length - 1);
      return body
          .split('","')
          .map((s) => s.replaceAll(r'\"', '"').replaceFirst(RegExp(r'^"'), '').replaceFirst(RegExp(r'"$'), ''))
          .toList();
    }
  }
}
