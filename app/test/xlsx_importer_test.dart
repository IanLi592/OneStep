import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/domain/xlsx_importer.dart';

/// 构造与实际导出一致的 XLSX:
///   行1: [卡牌盒, 记忆卡]          分组表头
///   行2: [空, 正面, 背面]           字段表头
///   行3+: [牌组, 正面, 背面]        数据
List<int> buildFixtureXlsx({bool emptyDeckCell = false}) {
  // 共享字符串表
  final shared = <String>[
    '卡牌盒', // 0
    '记忆卡', // 1
    '正面', // 2
    '背面', // 3
    '大模型', // 4
    '大语言模型的定义', // 5
    '大语言模型是基于深度神经网络构建的模型。', // 6
    'AI六大方向', // 7
    'CV/NLP/语音/推荐/RL/多模态', // 8
    '第二牌组', // 9
    '问题2', // 10
    '答案2', // 11
  ];
  final ssXml = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${shared.length}" uniqueCount="${shared.length}">');
  for (final s in shared) {
    ssXml.write('<si><t xml:space="preserve">${_esc(s)}</t></si>');
  }
  ssXml.write('</sst>');

  // 数据行(牌组列可为空,测试继承)
  final rows = <String>[
    '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>',
    '<row r="2"><c r="B2" t="s"><v>2</v></c><c r="C2" t="s"><v>3</v></c></row>',
    '<row r="3"><c r="A3" t="s"><v>4</v></c><c r="B3" t="s"><v>5</v></c><c r="C3" t="s"><v>6</v></c></row>',
    emptyDeckCell
        ? '<row r="4"><c r="B4" t="s"><v>7</v></c><c r="C4" t="s"><v>8</v></c></row>'
        : '<row r="4"><c r="A4" t="s"><v>4</v></c><c r="B4" t="s"><v>7</v></c><c r="C4" t="s"><v>8</v></c></row>',
    '<row r="5"><c r="A5" t="s"><v>9</v></c><c r="B5" t="s"><v>10</v></c><c r="C5" t="s"><v>11</v></c></row>',
    '<row r="6"><c r="A6" t="s"><v>9</v></c></row>', // 只有牌组、无内容 -> 应跳过
  ].join();

  final sheetXml = '<?xml version="1.0" encoding="UTF-8"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<dimension ref="A1:C6"/><sheetData>$rows</sheetData></worksheet>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml',
      '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
  add('xl/sharedStrings.xml', ssXml.toString());
  add('xl/worksheets/sheet1.xml', sheetXml);
  return ZipEncoder().encode(archive)!;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

void main() {
  test('解析标准结构:表头识别、牌组/正面/背面映射', () {
    final rows = XlsxImporter.parse(buildFixtureXlsx());
    // 数据行 = 第3/4/5行(第6行只有牌组名,应跳过) -> 3 条
    expect(rows, hasLength(3));

    expect(rows[0].deck, '大模型');
    expect(rows[0].front, '大语言模型的定义');
    expect(rows[0].back, '大语言模型是基于深度神经网络构建的模型。');

    expect(rows[1].deck, '大模型');
    expect(rows[1].front, 'AI六大方向');

    expect(rows[2].deck, '第二牌组');
    expect(rows[2].front, '问题2');
    expect(rows[2].back, '答案2');
  });

  test('牌组列为空时沿用上一行(合并单元格)', () {
    final rows = XlsxImporter.parse(buildFixtureXlsx(emptyDeckCell: true));
    expect(rows, hasLength(3));
    // 第 4 行牌组列为空,应继承上一行的"大模型"
    expect(rows[1].deck, '大模型');
    expect(rows[1].front, 'AI六大方向');
  });

  test('只含牌组无内容的行被跳过', () {
    final rows = XlsxImporter.parse(buildFixtureXlsx());
    // fixture 第 6 行只有牌组名,无正面/背面 -> 不应出现
    expect(rows.every((r) => r.front.isNotEmpty || r.back.isNotEmpty), isTrue);
    expect(rows.length, 3); // 数据行 3/4/5,跳过第 6 行
  });

  test('真实导出文件能解析', () {
    const path = r'D:\quickaccess\Downloads\大模型-2026-10-29_20_39_17.xlsx';
    if (!File(path).existsSync()) {
      markTestSkipped('样例文件不存在,跳过');
      return;
    }
    final rows = XlsxImporter.parse(File(path).readAsBytesSync());
    expect(rows.length, greaterThanOrEqualTo(2));
    // 第一条应是"大模型"牌组
    expect(rows.first.deck, '大模型');
    expect(rows.first.front, '大语言模型的定义');
    expect(rows.first.back, contains('深度神经网络'));
    // 第二条
    expect(rows[1].front, 'AI行业六大研究方向');
    // ignore: avoid_print
    print('真实文件解析出 ${rows.length} 条:');
    for (final r in rows) {
      // ignore: avoid_print
      print('  [${r.deck}] ${r.front} -> ${r.back.substring(0, r.back.length.clamp(0, 30))}');
    }
  });
}
