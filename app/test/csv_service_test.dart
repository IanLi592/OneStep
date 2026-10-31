import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:onestep/core/domain/csv_service.dart';

/// CSV 导入导出往返测试。
void main() {
  late OnestepDb db;
  late CollectionRepo repo;
  late CsvService csv;

  setUp(() async {
    db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    repo = CollectionRepo(db);
    csv = CsvService(repo);
  });

  tearDown(() async {
    await db.close();
  });

  test('导出空牌组只含表头', () async {
    final deck = (await repo.allDecks()).first;
    final out = await csv.exportDeck(deck.id);
    expect(out.trim(), '正面,背面,标签');
  });

  test('导出含英文逗号的字段被正确转义，且可往返', () async {
    final deck = (await repo.allDecks()).first;
    // 用 ASCII 逗号触发 CSV 引号转义；全角逗号不是分隔符、无需转义。
    await repo.createBasicNote(deckId: deck.id, front: 'hello, world', back: '"引号"测试', tags: ['a', 'b']);

    final out = await csv.exportDeck(deck.id);
    // 含英文逗号的字段应被引号包裹。
    expect(out, contains('"hello, world"'));

    // 往返：导入到另一个牌组，再导出比对。
    final deck2 = await repo.createDeck('导入目标');
    final n = await csv.importCsv(deck2.id, out);
    expect(n, 1);
    final out2 = await csv.exportDeck(deck2.id);
    expect(out2, contains('hello, world'));
    expect(out2, contains('引号'));
  });

  test('导入跳过表头并统计数量', () async {
    final deck = (await repo.allDecks()).first;
    const text = '正面,背面,标签\nhello,world,\nx,y,t1 t2\n';
    final n = await csv.importCsv(deck.id, text);
    expect(n, 2);
    final counts = await repo.deckCounts(deck.id);
    expect(counts.newCards, 2);
  });

  test('导入空行被忽略', () async {
    final deck = (await repo.allDecks()).first;
    const text = '正面,背面\na,b\n,\nc,d\n';
    final n = await csv.importCsv(deck.id, text);
    expect(n, 2);
  });

  test('标签按空格/逗号拆分', () async {
    final deck = (await repo.allDecks()).first;
    // 标签列含空格与逗号分隔的多个标签，整列用引号包裹成一个 CSV 字段。
    const text = '正面,背面,标签\na,b,"tag1 tag2,tag3"\n';
    await csv.importCsv(deck.id, text);
    final note = await db.select(db.notes).getSingle();
    expect(note.tags, contains('tag1'));
    expect(note.tags, contains('tag2'));
    expect(note.tags, contains('tag3'));
  });
}
