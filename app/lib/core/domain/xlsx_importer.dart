import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 一条从 XLSX 解析出的卡片行。
class XlsxRow {
  const XlsxRow({required this.deck, required this.front, required this.back});

  final String deck;
  final String front;
  final String back;

  @override
  String toString() => 'XlsxRow(deck=$deck, front=$front, back=$back)';
}

/// 解析闪记卡导出的 XLSX。
///
/// 实测结构(如"大模型-2026-10-29.xlsx"):
///   行1: [卡牌盒, 记忆卡]                <- 分组表头
///   行2: [空, 正面, 背面]                 <- 字段表头
///   行3: [大模型, 正文1, 正文2]            <- 数据
///   行4: [大模型, 正文3, 正文4]            <- 数据
///
/// 解析策略:
///  1. 解压 zip,读 sharedStrings(共享文本)与 sheet XML。
///  2. 定位含"正面/front"的表头行,据此确定 正面/背面 列下标;
///     牌组列 = 正面列 - 1(通常为 A 列)。找不到表头则回退为
///     [0]=牌组、[1]=正面、[2]=背面。
///  3. 数据行中牌组列为空时沿用上一行牌组(合并单元格场景)。
class XlsxImporter {
  /// 从 .xlsx 字节解析出卡片行。
  static List<XlsxRow> parse(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final shared = _readSharedStrings(archive);
    final rows = _readSheetRows(archive, shared);

    // 定位字段表头行,确定列映射。
    var frontCol = 1, backCol = 2, deckCol = 0;
    var headerRow = -1;
    for (var i = 0; i < rows.length; i++) {
      final cells = rows[i];
      final idx = cells.indexWhere(_isFrontHeader);
      if (idx >= 0) {
        headerRow = i;
        frontCol = idx;
        backCol = _indexOfHeader(cells, _frontAliases) >= 0 &&
                _indexOfHeader(cells, _backAliases) >= 0
            ? _indexOfHeader(cells, _backAliases)
            : idx + 1;
        deckCol = idx > 0 ? idx - 1 : -1; // 无牌组列
        break;
      }
    }
    // 找不到表头:回退为 3 列布局(牌组/正面/背面)。
    if (headerRow < 0) {
      headerRow = -1;
      deckCol = 0;
      frontCol = 1;
      backCol = 2;
    }

    final out = <XlsxRow>[];
    var lastDeck = '';
    for (var i = headerRow + 1; i < rows.length; i++) {
      final cells = rows[i];
      String at(int c) => (c >= 0 && c < cells.length) ? cells[c].trim() : '';

      final front = at(frontCol);
      final back = at(backCol);
      if (front.isEmpty && back.isEmpty) continue; // 跳过空行

      // 牌组列为空则沿用上一行(合并单元格)。
      final deckCell = deckCol >= 0 ? at(deckCol) : '';
      if (deckCell.isNotEmpty) lastDeck = deckCell;
      final deck = deckCell.isNotEmpty ? deckCell : lastDeck;

      out.add(XlsxRow(deck: deck, front: front, back: back));
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // 内部解析
  // ---------------------------------------------------------------------

  static const _frontAliases = ['正面', 'front', 'question', '问题', '问'];
  static const _backAliases = ['背面', 'back', 'answer', '答案', '答'];

  static bool _isFrontHeader(String s) {
    final t = s.trim().toLowerCase();
    return _frontAliases.any((a) => t == a.toLowerCase());
  }

  static int _indexOfHeader(List<String> cells, List<String> aliases) {
    for (var i = 0; i < cells.length; i++) {
      final t = cells[i].trim().toLowerCase();
      if (aliases.any((a) => t == a.toLowerCase())) return i;
    }
    return -1;
  }

  static List<String> _readSharedStrings(Archive archive) {
    final entry = archive.findFile('xl/sharedStrings.xml');
    if (entry == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
    return doc
        .findAllElements('si')
        .map((si) => si.findAllElements('t').map((t) => t.innerText).join())
        .toList();
  }

  /// 读取第一个 worksheet,返回"每行 -> 每列值"的二维数组。
  static List<List<String>> _readSheetRows(Archive archive, List<String> shared) {
    final entry = archive.files
        .where((f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (entry.isEmpty) return const [];

    final doc = XmlDocument.parse(utf8.decode(entry.first.content as List<int>));
    final rows = <List<String>>[];

    for (final rowEl in doc.findAllElements('sheetData').first.children) {
      if (rowEl is! XmlElement || rowEl.name.local != 'row') continue;
      final cells = <String>[];
      for (final c in rowEl.childElements) {
        if (c.name.local != 'c') continue;
        final col = _colIndexOf(c.getAttribute('r'));
        while (cells.length <= col) {
          cells.add('');
        }
        cells[col] = _cellValue(c, shared);
      }
      rows.add(cells);
    }
    return rows;
  }

  /// 从单元格引用(如 "C3")得到列下标(0-based)。
  static int _colIndexOf(String? ref) {
    if (ref == null || ref.isEmpty) return 0;
    var col = 0;
    for (final ch in ref.codeUnits) {
      final isUpper = ch >= 0x41 && ch <= 0x5A;
      final isLower = ch >= 0x61 && ch <= 0x7A;
      if (!isUpper && !isLower) break;
      col = col * 26 + (isUpper ? ch - 0x41 : ch - 0x61) + 1;
    }
    return col > 0 ? col - 1 : 0;
  }

  /// 取单元格文本:`t="s"` 表示引用 sharedStrings;否则取 `<v>` 或内联 `<is><t>`。
  static String _cellValue(XmlElement c, List<String> shared) {
    final t = c.getAttribute('t');
    if (t == 's') {
      final v = c.getElement('v')?.innerText.trim();
      if (v == null || v.isEmpty) return '';
      final i = int.tryParse(v);
      return (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
    }
    if (t == 'inlineStr') {
      return c.getElement('is')?.findAllElements('t').map((e) => e.innerText).join() ?? '';
    }
    return c.getElement('v')?.innerText ?? '';
  }
}
