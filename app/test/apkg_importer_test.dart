import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/apkg_importer.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// 构造一个最小的"经典" APKG（zip 内含 collection.anki2 SQLite）。
List<int> buildClassicApkg() {
  final tmp = Directory.systemTemp.createTempSync('apkg_fixture');
  final colPath = '${tmp.path}/collection.anki2';
  final db = sq.sqlite3.open(colPath);

  db.execute('''
    CREATE TABLE col (id integer primary key, ver integer, dty integer, usn integer,
      ls integer, conf text, models text, decks text, dconf text, tags text);
  ''');
  db.execute('''
    CREATE TABLE notes (id integer primary key, guid text, mid integer, mod integer,
      usn integer, tags text, flds text, sfld text, csum integer, flags integer, data text);
  ''');
  db.execute('''
    CREATE TABLE cards (id integer primary key, nid integer, did integer, ord integer,
      mod integer, usn integer, type integer, queue integer, due integer, ivl integer,
      factor integer, reps integer, lapses integer, left integer, odue integer,
      odid integer, flags integer, data text);
  ''');

  const models = '''
  {"100":{"id":100,"name":"Basic","type":0,
    "flds":[{"name":"Front","ord":0},{"name":"Back","ord":1}],
    "tmpls":[{"name":"Card 1","qfmt":"{{Front}}","afmt":"{{FrontSide}}<hr id=answer>{{Back}}"}]}}
  ''';
  const decks = '''
  {"1":{"id":1,"name":"Default"},"200":{"id":200,"name":"Spanish::Basics"}}
  ''';
  db.execute(
      "INSERT INTO col (id,ver,models,decks) VALUES (1,11,'${models.replaceAll("'", "''")}','${decks.replaceAll("'", "''")}')");

  // 两条笔记（第二条带标签、含 \x1f 分隔的两个字段）
  db.execute("INSERT INTO notes (id,guid,mid,tags,flds,sfld) VALUES (10,'g1',100,'','hola\x1fhola','hola')");
  db.execute("INSERT INTO notes (id,guid,mid,tags,flds,sfld) VALUES (11,'g2',100,' vocab greeting','adios\x1fgoodbye','adios')");

  // 两张卡：一张新卡（queue=0），一张复习卡（queue=2, ivl=10）
  db.execute('INSERT INTO cards (id,nid,did,ord,type,queue,due,ivl,factor,reps,lapses) '
      'VALUES (1000,10,200,0,0,0,1,0,2500,0,0)');
  db.execute('INSERT INTO cards (id,nid,did,ord,type,queue,due,ivl,factor,reps,lapses) '
      'VALUES (1001,11,200,0,2,2,500,10,2500,5,1)');

  db.dispose();

  // 打成 zip，内含 collection.anki2。
  final colBytes = File(colPath).readAsBytesSync();
  final archive = Archive();
  archive.addFile(ArchiveFile('collection.anki2', colBytes.length, colBytes));
  final zipBytes = ZipEncoder().encode(archive)!;
  tmp.deleteSync(recursive: true);
  return zipBytes;
}

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

  test('导入经典 APKG：笔记/卡片/字段/标签', () async {
    final importer = ApkgImporter(repo);
    final result = await importer.importFromBytes(buildClassicApkg());

    expect(result.notes, 2);
    expect(result.cards, 2);
    expect(result.decks, 1);

    // 牌组名取第一个非 Default 牌组的顶层（"Spanish"）。
    final decks = await repo.allDecks();
    expect(decks.any((d) => d.name == 'Spanish'), isTrue);

    // 标签被保留。
    final notes = await db.select(db.notes).get();
    expect(notes.any((n) => n.tags.contains('vocab')), isTrue);

    // 字段被正确按 \x1f 拆分并 JSON 存储。
    final n0 = notes.firstWhere((n) => n.fields.contains('hola'));
    final decoded = jsonDecode(n0.fields) as List<dynamic>;
    expect(decoded[0], 'hola');
    expect(decoded[1], 'hola');
  });

  test('导入的卡片带正确的调度状态', () async {
    final importer = ApkgImporter(repo);
    await importer.importFromBytes(buildClassicApkg());

    final cards = await db.select(db.cards).get();
    // 新卡 queue=0
    expect(cards.any((c) => c.queue == Queue.newCard), isTrue);
    // 复习卡 queue=2 且 stability 近似 ivl(10)
    final review = cards.firstWhere((c) => c.queue == Queue.review);
    expect(review.stability, closeTo(10.0, 0.01));
    expect(review.reps, 5);
    expect(review.lapses, 1);
  });

  test('新版 APKG（无 collection.anki2）明确报错', () async {
    // 只放一个 anki21b，不含 anki2。
    final archive = Archive();
    final fake = List<int>.filled(10, 0);
    archive.addFile(ArchiveFile('collection.anki21b', fake.length, fake));
    final zip = ZipEncoder().encode(archive)!;

    final importer = ApkgImporter(repo);
    expect(
      () => importer.importFromBytes(zip),
      throwsA(isA<ApkgImportException>()),
    );
  });

  test('非 APKG（无集合文件）明确报错', () async {
    final archive = Archive();
    final fake = List<int>.filled(4, 1);
    archive.addFile(ArchiveFile('readme.txt', fake.length, fake));
    final zip = ZipEncoder().encode(archive)!;

    final importer = ApkgImporter(repo);
    expect(
      () => importer.importFromBytes(zip),
      throwsA(isA<ApkgImportException>()),
    );
  });
}
