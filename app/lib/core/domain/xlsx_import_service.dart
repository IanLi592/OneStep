import '../data/database.dart';
import 'collection_repo.dart';
import 'xlsx_importer.dart';

/// XLSX 导入结果。
class XlsxImportResult {
  const XlsxImportResult({
    required this.rows,
    required this.decksCreated,
    required this.decksReused,
    required this.cardsCreated,
  });

  final int rows;
  final int decksCreated;
  final int decksReused;
  final int cardsCreated;
}

/// 把解析出的 XLSX 行写入数据库:按牌组名建/复用分组,逐行建卡。
///
/// 牌组名为空的行归入 [fallbackDeckName](默认"导入")。
class XlsxImportService {
  XlsxImportService(this.repo);

  final CollectionRepo repo;

  /// 从 .xlsx 字节导入。返回统计。
  Future<XlsxImportResult> importBytes(
    List<int> bytes, {
    String fallbackDeckName = '导入',
  }) async {
    final rows = XlsxImporter.parse(bytes);
    if (rows.isEmpty) {
      return const XlsxImportResult(
        rows: 0,
        decksCreated: 0,
        decksReused: 0,
        cardsCreated: 0,
      );
    }

    // 先把所有牌组名解析成 deckId(建或复用)。
    final existing = await repo.allDecks();
    final byName = <String, Deck>{};
    for (final d in existing) {
      byName.putIfAbsent(d.name, () => d);
    }

    var decksCreated = 0;
    var decksReused = 0;
    final deckIds = <String, String>{}; // 牌组名 -> deckId

    Future<String> deckIdFor(String name) async {
      final key = name.isEmpty ? fallbackDeckName : name;
      if (deckIds.containsKey(key)) return deckIds[key]!;
      if (byName.containsKey(key)) {
        decksReused++;
        deckIds[key] = byName[key]!.id;
        return byName[key]!.id;
      }
      final created = await repo.createDeck(key);
      byName[key] = created;
      decksCreated++;
      deckIds[key] = created.id;
      return created.id;
    }

    var cardsCreated = 0;
    for (final row in rows) {
      final deckId = await deckIdFor(row.deck);
      // 正面必填;背面可为空(仍建卡)。
      final front = row.front.isNotEmpty ? row.front : row.back;
      final back = row.front.isNotEmpty ? row.back : '';
      if (front.isEmpty) continue;
      await repo.createBasicNote(deckId: deckId, front: front, back: back);
      cardsCreated++;
    }

    return XlsxImportResult(
      rows: rows.length,
      decksCreated: decksCreated,
      decksReused: decksReused,
      cardsCreated: cardsCreated,
    );
  }
}
