import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:onestep/core/domain/widget_updater.dart';

/// 小组件数据桥测试：totalDue 汇总所有牌组今日待复习数。
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

  test('totalDue 为空库时为 0', () async {
    final updater = WidgetUpdater(repo);
    expect(await updater.totalDue(), 0);
  });

  test('totalDue 汇总多牌组的待复习数', () async {
    final deckA = (await repo.allDecks()).first;
    final deckB = await repo.createDeck('第二牌组');
    await repo.createBasicNote(deckId: deckA.id, front: 'q1', back: 'a1');
    await repo.createBasicNote(deckId: deckA.id, front: 'q2', back: 'a2');
    await repo.createBasicNote(deckId: deckB.id, front: 'q3', back: 'a3');

    final updater = WidgetUpdater(repo);
    expect(await updater.totalDue(), 3);
  });

  test('totalDue 反映复习后的剩余（新卡用完则减少）', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'q1', back: 'a1');
    final updater = WidgetUpdater(repo);
    expect(await updater.totalDue(), 1);

    // 作答后，新卡额度用尽 → totalDue 归 0。
    final card = (await repo.dueCards(deck.id)).first;
    await repo.answerCard(card, Rating.good);
    expect(await updater.totalDue(), 0);
  });

  test('非 Android 平台 push 不抛异常（静默跳过）', () async {
    // 测试环境 defaultTargetPlatform 通常是 android 或 linux；push 不应抛出。
    final updater = WidgetUpdater(repo);
    await expectLater(updater.push(), completes);
  });
}
