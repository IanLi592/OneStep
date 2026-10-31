import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/collection_repo.dart';

/// 完形填空建卡集成测试：不同 cN 序号各生成一张卡片。
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

  test('无 cloze 文本不建任何记录', () async {
    final deck = (await repo.allDecks()).first;
    final note = await repo.createClozeNote(deckId: deck.id, text: '纯文本无挖空');
    expect(note, isNull);
    expect((await db.select(db.notes).get()).length, 0); // 不含 seed 的类型
  });

  test('两个不同序号生成两张卡片', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createClozeNote(deckId: deck.id, text: '{{c1::红}}和{{c2::蓝}}');
    final cards = await db.select(db.cards).get();
    expect(cards.length, 2);
    // templateIndex 分别为 0 和 1。
    final idxs = cards.map((c) => c.templateIndex).toSet();
    expect(idxs, {0, 1});
  });

  test('同序号多处挖空只生成一张卡片', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createClozeNote(deckId: deck.id, text: '{{c1::红}}和{{c1::红again}}');
    final cards = await db.select(db.cards).get();
    expect(cards.length, 1);
  });

  test('完形填空笔记类型被自动创建且标记 isCloze', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createClozeNote(deckId: deck.id, text: '{{c1::红}}');
    final types = await db.select(db.noteTypes).get();
    expect(types.any((t) => t.isCloze), isTrue);
  });

  test('三张 cloze 卡片进入复习队列', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createClozeNote(
        deckId: deck.id, text: '{{c1::红}}{{c2::蓝}}{{c3::绿}}');
    final due = await repo.dueCards(deck.id);
    expect(due.length, 3);
  });
}
