import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/browser_service.dart';
import 'package:onestep/core/domain/collection_repo.dart';

/// 卡片浏览器搜索/过滤/操作测试。
void main() {
  late OnestepDb db;
  late CollectionRepo repo;
  late BrowserService browser;

  setUp(() async {
    db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    repo = CollectionRepo(db);
    browser = BrowserService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    final deck = (await repo.allDecks()).first;
    await repo.createBasicNote(deckId: deck.id, front: 'hola', back: '你好', tags: ['greet']);
    await repo.createBasicNote(deckId: deck.id, front: 'adios', back: '再见', tags: ['greet', 'bye']);
    await repo.createBasicNote(deckId: deck.id, front: 'perro', back: '狗', tags: ['animal']);
  }

  test('无过滤时返回全部卡片', () async {
    await seed();
    final items = await browser.search(const CardQuery());
    expect(items.length, 3);
  });

  test('按文本过滤（正面/背面）', () async {
    await seed();
    expect((await browser.search(const CardQuery(text: 'hola'))).length, 1);
    expect((await browser.search(const CardQuery(text: '再见'))).length, 1);
    expect((await browser.search(const CardQuery(text: 'zzz'))).length, 0);
  });

  test('按标签过滤', () async {
    await seed();
    final greet = await browser.search(const CardQuery(tag: 'greet'));
    expect(greet.length, 2);
    final animal = await browser.search(const CardQuery(tag: 'animal'));
    expect(animal.length, 1);
  });

  test('按状态过滤：新卡 vs 挂起', () async {
    await seed();
    final newCards = await browser.search(const CardQuery(state: CardState.newCard));
    expect(newCards.length, 3);

    // 挂起一张后再查。
    await browser.setSuspended(newCards.first.card.id, true);
    final suspended = await browser.search(const CardQuery(state: CardState.suspended));
    expect(suspended.length, 1);
    final stillNew = await browser.search(const CardQuery(state: CardState.newCard));
    expect(stillNew.length, 2);
  });

  test('文本 + 标签组合过滤', () async {
    await seed();
    final r = await browser.search(const CardQuery(text: 'adios', tag: 'bye'));
    expect(r.length, 1);
    expect(r.first.displayFront, 'adios');
  });

  test('删除卡片后不再出现在结果中', () async {
    await seed();
    final all = await browser.search(const CardQuery());
    await browser.deleteCard(all.first.card.id);
    final after = await browser.search(const CardQuery());
    expect(after.length, 2);
  });

  test('allTags 汇总去重排序', () async {
    await seed();
    final tags = await browser.allTags();
    expect(tags, ['animal', 'bye', 'greet']);
  });

  test('cloze 卡片 displayFront 去掉挖空标记', () async {
    final deck = (await repo.allDecks()).first;
    await repo.createClozeNote(deckId: deck.id, text: '水在{{c1::0}}度沸腾');
    final items = await browser.search(const CardQuery());
    expect(items.length, 1);
    expect(items.first.displayFront, '水在0度沸腾');
  });
}
