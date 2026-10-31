import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide Column;

import 'collection_repo.dart';

/// CSV 导入导出（备份与迁移）。
///
/// 导出格式：两列 `正面,背面`，可选第三列 `标签`。带表头。
/// 导入：读取同样的列结构，逐行建笔记。用于从其他闪记卡应用迁移。
class CsvService {
  CsvService(this.repo);

  final CollectionRepo repo;

  /// 导出：用 \n 作为换行，保证跨平台往返一致。
  static const ListToCsvConverter _toCsv = ListToCsvConverter(eol: '\n');

  /// 解析：用 \n 作为换行；导入前先把 \r\n 归一化为 \n。
  static const CsvToListConverter _fromCsv = CsvToListConverter(eol: '\n');

  /// 导出某牌组全部笔记为 CSV 文本（正面, 背面, 标签）。
  Future<String> exportDeck(String deckId) async {
    final db = repo.db;
    // 该牌组下所有卡片对应的笔记（去重）。
    final cardRows = await (db.select(db.cards)
          ..where((c) => c.deckId.equals(deckId) & c.deleted.equals(false)))
        .get();
    final noteIds = cardRows.map((c) => c.noteId).toSet();

    final rows = <List<dynamic>>[
      ['正面', '背面', '标签'],
    ];
    for (final nid in noteIds) {
      final note =
          await (db.select(db.notes)..where((n) => n.id.equals(nid))).getSingleOrNull();
      if (note == null) continue;
      final fields = _decodeFields(note.fields);
      final front = fields.isNotEmpty ? fields[0] : '';
      final back = fields.length > 1 ? fields[1] : '';
      rows.add([front, back, note.tags]);
    }
    return _toCsv.convert(rows);
  }

  /// 从 CSV 文本导入到指定牌组。返回导入的笔记数。
  Future<int> importCsv(String deckId, String csvText) async {
    // 归一化换行：把 \r\n / \r 统一为 \n，兼容 Excel/Windows 导出。
    final normalized = csvText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = _fromCsv.convert(normalized);
    if (rows.isEmpty) return 0;

    // 跳过表头（若首列是"正面"/"front"）。
    var start = 0;
    final first = rows[0];
    if (first.isNotEmpty &&
        (first[0].toString().trim() == '正面' || first[0].toString().trim().toLowerCase() == 'front')) {
      start = 1;
    }

    var count = 0;
    for (var i = start; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final front = row[0].toString();
      final back = row.length > 1 ? row[1].toString() : '';
      final tags = row.length > 2 ? row[2].toString() : '';
      if (front.trim().isEmpty && back.trim().isEmpty) continue;
      await repo.createBasicNote(
        deckId: deckId,
        front: front,
        back: back,
        tags: tags.isEmpty ? const [] : tags.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList(),
      );
      count++;
    }
    return count;
  }

  List<String> _decodeFields(String json) {
    final inner = json.trim();
    if (!inner.startsWith('[') || !inner.endsWith(']')) return [inner];
    try {
      final decoded = jsonDecode(inner) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      final body = inner.substring(1, inner.length - 1);
      return body.split('","').map((s) => s.replaceAll(r'\"', '"')).toList();
    }
  }
}
