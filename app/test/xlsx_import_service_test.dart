import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:onestep/core/domain/xlsx_import_service.dart';

/// 构造与闪记盒导出同构的 xlsx：
///   行1 [卡牌盒, 记忆卡] / 行2 [空, 正面, 背面] / 行3+ [牌组, 正面, 背面]
List<int> buildXlsx(List<List<String>> dataRows) {
  final shared = <String>['卡牌盒', '记忆卡', '正面', '背面'];
  for (final r in dataRows) {
    for (final c in r) {
      if (c.isNotEmpty && !shared.contains(c)) shared.add(c);
    }
  }

  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  final rows = <String>[
    '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>',
    '<row r="2"><c r="B2" t="s"><v>2</v></c><c r="C2" t="s"><v>3</v></c></row>',
  ];
  for (var i = 0; i < dataRows.length; i++) {
    final r = dataRows[i];
    final ref = i + 3;
    final cs = <String>[];
    for (var c = 0; c < r.length; c++) {
      if (r[c].isEmpty) continue;
      cs.add('<c r="${String.fromCharCode(65 + c)}$ref" t="s">'
          '<v>${shared.indexOf(r[c])}</v></c>');
    }
    rows.add('<row r="$ref">${cs.join()}</row>');
  }

  final ss = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  for (final s in shared) {
    ss.write('<si><t xml:space="preserve">${esc(s)}</t></si>');
  }
  ss.write('</sst>');

  final sheet = '<?xml version="1.0" encoding="UTF-8"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>${rows.join()}</sheetData></worksheet>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml',
      '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
  add('xl/sharedStrings.xml', ss.toString());
  add('xl/worksheets/sheet1.xml', sheet);
  return ZipEncoder().encode(archive)!;
}

void main() {
  late OnestepDb db;
  late CollectionRepo repo;

  setUp(() async {
    db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    repo = CollectionRepo(db);
  });

  tearDown(() async => db.close());

  /// 取某分组的完整路径（根 -> 自身）。
  Future<List<String>> pathOf(String name) async {
    final decks = await repo.allDecks();
    final d = decks.firstWhere((e) => e.name == name);
    return repo.deckPathNames(d.id);
  }

  test('单元格用 :: 路径时自动分层建组', () async {
    final bytes = buildXlsx([
      ['大模型::深度学习::卷积', 'q1', 'a1'],
      ['大模型::深度学习::Transformer', 'q2', 'a2'],
      ['大模型::数学基础', 'q3', 'a3'],
    ]);
    final res = await XlsxImportService(repo).importBytes(bytes);

    expect(res.cardsCreated, 3);
    expect(res.maxDepthReached, 3);
    expect(await pathOf('卷积'), ['大模型', '深度学习', '卷积']);
    expect(await pathOf('Transformer'), ['大模型', '深度学习', 'Transformer']);
    expect(await pathOf('数学基础'), ['大模型', '数学基础']);
    // 中间层只建一次
    final decks = await repo.allDecks();
    expect(decks.where((d) => d.name == '大模型').length, 1);
    expect(decks.where((d) => d.name == '深度学习').length, 1);
  });

  test('闪记盒导出：牌组列只有叶子名时，从文件名补父路径', () async {
    final bytes = buildXlsx([
      ['英文缩写', 'RRF', 'Reciprocal Rank Fusion'],
      ['英文缩写', 'SSE', 'Server-Sent Events'],
    ]);
    final res = await XlsxImportService(repo).importBytes(
      bytes,
      sourceFileName: '大模型-英文缩写-2026-11-02_10_03_10.xlsx',
    );

    expect(res.cardsCreated, 2);
    expect(res.importedPaths, ['大模型 › 英文缩写']);
    expect(await pathOf('英文缩写'), ['大模型', '英文缩写']);
  });

  test('文件名没有时间戳就不采信（不瞎猜层级）', () async {
    final bytes = buildXlsx([
      ['英文缩写', 'q', 'a'],
    ]);
    await XlsxImportService(repo)
        .importBytes(bytes, sourceFileName: '随便起的名字.xlsx');
    expect(await pathOf('英文缩写'), ['英文缩写']);
  });

  test('组名本身含 - 时不会被切错', () async {
    final bytes = buildXlsx([
      ['A-B', 'q', 'a'],
    ]);
    // 文件名末段是 'B'，与单元格 'A-B' 不相等 -> 不补父路径，整名保留。
    await XlsxImportService(repo)
        .importBytes(bytes, sourceFileName: 'A-B-2026-11-02_10_03_10.xlsx');
    expect(await pathOf('A-B'), ['A-B']);
  });

  test('超过 5 层：整批中止，一个组都不建', () async {
    final bytes = buildXlsx([
      ['A::B::C::D::E', 'ok', 'a'],
      ['A::B::C::D::E::F', 'bad', 'a'],
    ]);
    final res = await XlsxImportService(repo).importBytes(bytes);

    expect(res.aborted, isTrue);
    expect(res.cardsCreated, 0);
    expect(res.rejectedPaths, ['A › B › C › D › E › F']);
    final decks = await repo.allDecks();
    expect(decks.where((d) => d.name == 'A'), isEmpty,
        reason: '中止必须是原子的，不能留下半棵树');
  });

  test('第 5 层是允许的边界', () async {
    final bytes = buildXlsx([
      ['A::B::C::D::E', 'q', 'a'],
    ]);
    final res = await XlsxImportService(repo).importBytes(bytes);
    expect(res.aborted, isFalse);
    expect(res.maxDepthReached, 5);
    expect(await pathOf('E'), ['A', 'B', 'C', 'D', 'E']);
  });

  test('重复导入同一文件不重复建组', () async {
    final bytes = buildXlsx([
      ['大模型::深度学习', 'q1', 'a1'],
    ]);
    final first = await XlsxImportService(repo).importBytes(bytes);
    final second = await XlsxImportService(repo).importBytes(bytes);

    expect(first.decksCreated, 2);
    expect(second.decksCreated, 0);
    expect(second.decksReused, greaterThan(0));
    final decks = await repo.allDecks();
    expect(decks.where((d) => d.name == '深度学习').length, 1);
  });

  test('复用数按分组去重，不随行数放大', () async {
    // decksReused 统计的是"复用了几个导入前就存在的分组"，不是"命中了几次"。
    // 以前每行每段各 +1：20 行挂同一条 3 层路径会报复用 60 个分组，
    // 导入结果页那个数字就完全没有意义了（真实文件是 320 行 × 3 段 = 960）。
    final first = await XlsxImportService(repo).importBytes(buildXlsx([
      for (var i = 0; i < 20; i++) ['大模型::深度学习::卷积', 'q$i', 'a$i'],
    ]));
    expect(first.cardsCreated, 20);
    expect(first.decksCreated, 3);
    expect(first.decksReused, 0, reason: '这 3 个组都是本次新建的，谈不上复用');

    final second = await XlsxImportService(repo).importBytes(buildXlsx([
      for (var i = 0; i < 20; i++) ['大模型::深度学习::池化', 'p$i', 'a$i'],
    ]));
    expect(second.decksCreated, 1, reason: '只有「池化」是新建的');
    expect(second.decksReused, 2,
        reason: '20 行反复路过「大模型」「深度学习」，也只能算 2 个分组');
  });

  test('旧的扁平文件照旧导入（向后兼容）', () async {
    final bytes = buildXlsx([
      ['大模型', 'q1', 'a1'],
      ['第二组', 'q2', 'a2'],
    ]);
    final res = await XlsxImportService(repo).importBytes(bytes);
    expect(res.cardsCreated, 2);
    expect(res.maxDepthReached, 1);
    expect(await pathOf('大模型'), ['大模型']);
  });

  test('牌组列空值沿用上一行的完整路径（合并单元格）', () async {
    final bytes = buildXlsx([
      ['大模型::深度学习', 'q1', 'a1'],
      ['', 'q2', 'a2'],
    ]);
    final res = await XlsxImportService(repo).importBytes(bytes);
    expect(res.cardsCreated, 2);
    final decks = await repo.allDecks();
    final leaf = decks.firstWhere((d) => d.name == '深度学习');
    expect((await repo.deckCounts(leaf.id)).totalCards, 2);
  });

  test('不同父下的同名叶子各归其组（旧实现会撞成一个）', () async {
    final bytes = buildXlsx([
      ['A组::算法', 'q1', 'a1'],
      ['B组::算法', 'q2', 'a2'],
    ]);
    await XlsxImportService(repo).importBytes(bytes);

    final decks = await repo.allDecks();
    final leaves = decks.where((d) => d.name == '算法').toList();
    expect(leaves, hasLength(2));
    expect((await repo.deckCounts(leaves[0].id)).totalCards, 1);
    expect((await repo.deckCounts(leaves[1].id)).totalCards, 1);
  });

  // -------------------------------------------------------------------------
  // 真实文件端到端：直接吃闪记盒导出的原件，验的是"用户手上那份文件"
  // 而不是我构造的理想 fixture。文件不在就 skip（与既有 xlsx 用例同策略）。
  // -------------------------------------------------------------------------

  const realFiles = [
    r'D:\quickaccess\Downloads\大模型-英文缩写-2026-11-02_10_03_10..xlsx',
    r'D:\quickaccess\Downloads\大模型-面试重点-2026-11-02_10_02_50..xlsx',
  ];

  for (final path in realFiles) {
    final name = path.split(r'\').last;
    test('真实导出文件 $name：层级建到 大模型 之下', () async {
      final f = File(path);
      if (!f.existsSync()) {
        markTestSkipped('样例文件不存在，跳过');
        return;
      }
      final res = await XlsxImportService(repo)
          .importBytes(await f.readAsBytes(), sourceFileName: name);

      expect(res.aborted, isFalse);
      expect(res.cardsCreated, greaterThan(0));
      final leaf = name.split('-')[1]; // 大模型-英文缩写-... -> 英文缩写
      expect(res.importedPaths, ['大模型 › $leaf']);
      expect(res.maxDepthReached, 2);

      final decks = await repo.allDecks();
      final node = decks.firstWhere((d) => d.name == leaf);
      expect(await repo.deckPathNames(node.id), ['大模型', leaf]);
      expect((await repo.deckCounts(node.id)).totalCards, res.cardsCreated);
    });
  }

  test('两个真实文件连续导入：都挂在同一个「大模型」下且不重复建父组', () async {
    final files = realFiles.map(File.new).where((f) => f.existsSync()).toList();
    if (files.length < 2) {
      markTestSkipped('样例文件不全，跳过');
      return;
    }
    for (final f in files) {
      await XlsxImportService(repo)
          .importBytes(await f.readAsBytes(), sourceFileName: f.uri.pathSegments.last);
    }
    final decks = await repo.allDecks();
    expect(decks.where((d) => d.name == '大模型').length, 1,
        reason: '第二个文件必须复用已建的父组');
    expect(decks.where((d) => d.name == '英文缩写' || d.name == '面试重点').length, 2);
  });
}
