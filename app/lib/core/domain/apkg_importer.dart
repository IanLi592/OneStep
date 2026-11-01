import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:sqlite3/sqlite3.dart';

import '../data/database.dart';
import 'collection_repo.dart';

/// APKG 只读导入的结果。
class ApkgImportResult {
  const ApkgImportResult({
    required this.decks,
    required this.notes,
    required this.cards,
    this.skippedNoteTypes = const [],
    this.message = '',
  });

  final int decks;
  final int notes;
  final int cards;
  final List<String> skippedNoteTypes;
  final String message;
}

/// APKG（Anki 导出包）只读导入。
///
/// APKG 是一个 zip，内含：
///  - `collection.anki2`（经典 SQLite 集合）或 `collection.anki21b`（新版 zstd+protobuf）
///  - `media`（数字到文件名的 JSON 映射），以及若干数字命名的媒体文件
///
/// 本实现支持**经典 SQLite 格式**（collection.anki2）。遇到新版格式会明确报错，
/// 不静默失败。干净按公开格式规范解析，不复用 Anki 源码。
///
/// 注意：Anki 的 SM-2 调度状态与 FSRS 状态不同。导入时用"间隔≈稳定度"做合理近似，
/// 使卡片在 FSRS 下从一个合理状态继续；不追求逐位复刻 Anki 的间隔。
class ApkgImporter {
  ApkgImporter(this.repo);

  final CollectionRepo repo;

  /// Anki 字段分隔符（ASCII Unit Separator, 0x1F）。
  static const String _fldSep = '\x1f';

  /// 从 .apkg 文件导入。返回导入统计。
  Future<ApkgImportResult> importFromFile(String apkgPath, {String? targetDeckName}) async {
    final bytes = File(apkgPath).readAsBytesSync();
    return importFromBytes(bytes, targetDeckName: targetDeckName);
  }

  /// 从 .apkg 字节导入。
  Future<ApkgImportResult> importFromBytes(List<int> bytes, {String? targetDeckName}) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final colEntry = archive.findFile('collection.anki2');
    if (colEntry == null) {
      if (archive.findFile('collection.anki21b') != null) {
        throw ApkgImportException(
            '这是新版 APKG（zstd+protobuf）格式，当前版本暂只支持经典 collection.anki2 格式。'
            '请在旧版 Anki 导出，或等待后续版本支持。');
      }
      throw ApkgImportException('APKG 中未找到 collection.anki2 集合文件。');
    }

    // 解压集合 SQLite 到临时文件（sqlite3 需要随机访问，不能用内存流）。
    final colBytes = colEntry.content as List<int>;
    final tmpDir = Directory.systemTemp.createTempSync('onestep_apkg');
    final colFile = File('${tmpDir.path}/collection.anki2');
    colFile.writeAsBytesSync(colBytes);

    try {
      final db = sqlite3.open(colFile.path);
      try {
        return await _importFromCollection(db, targetDeckName);
      } finally {
        db.dispose();
      }
    } finally {
      try {
        tmpDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<ApkgImportResult> _importFromCollection(Database db, String? targetDeckName) async {
    final colRows = db.select('SELECT models, decks FROM col LIMIT 1');
    if (colRows.isEmpty) {
      throw ApkgImportException('集合为空（无 col 记录）。');
    }
    final modelsJson = jsonDecode(colRows.first['models'] as String) as Map<String, dynamic>;
    final decksJson = jsonDecode(colRows.first['decks'] as String) as Map<String, dynamic>;

    // note type id -> (name, 字段名列表)。
    final noteTypeNames = <String, String>{};
    final noteTypeFields = <String, List<String>>{};
    for (final entry in modelsJson.entries) {
      final m = entry.value as Map<String, dynamic>;
      final name = (m['name'] as String?) ?? '未命名类型';
      final flds = ((m['flds'] as List?) ?? [])
          .map((f) => ((f as Map)['name'] as String?) ?? '')
          .toList();
      noteTypeNames[entry.key] = name;
      noteTypeFields[entry.key] = flds;
    }

    // 为每种源笔记类型创建一个对应的本应用笔记类型，保留字段语义。
    final typeMapping = <String, String>{};
    final existing = await (repo.db.select(repo.db.noteTypes)
          ..where((t) => t.deleted.equals(false)))
        .get();
    final basic = existing.first;

    final skippedTypes = <String>[];
    for (final mid in noteTypeNames.keys) {
      final srcName = noteTypeNames[mid]!;
      final fields = noteTypeFields[mid] ?? const <String>[];
      final isCloze = _isClozeModel(modelsJson[mid] as Map<String, dynamic>);
      if (isCloze) {
        skippedTypes.add('$srcName（完形填空，按普通字段导入）');
      }
      final names = fields.isEmpty ? const <String>['正面', '背面'] : fields;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ntId = newId();
      final templates = jsonEncode([
        {
          'name': '卡片 1',
          'qfmt': '{{${names.first}}}',
          'afmt':
              '{{${names.first}}}<hr id=answer>${names.length > 1 ? '{{${names[1]}}}' : ''}',
        }
      ]);
      await repo.db.into(repo.db.noteTypes).insert(NoteTypesCompanion.insert(
            id: ntId,
            name: srcName,
            fields: jsonEncode(names),
            templates: templates,
            isCloze: Value(isCloze),
            version: now,
          ));
      typeMapping[mid] = ntId;
    }
    if (typeMapping.isEmpty) {
      for (final mid in noteTypeNames.keys) {
        typeMapping[mid] = basic.id;
      }
    }

    // 牌组：把 Anki 的 "::" 嵌套名拍平到一个目标牌组（导入 MVP）。
    final deckIdMap = <String, String>{};
    final deckNames = <String, String>{};
    for (final entry in decksJson.entries) {
      final d = entry.value as Map<String, dynamic>;
      deckNames[entry.key] = (d['name'] as String?) ?? '';
    }

    String rootDeckName = targetDeckName ?? 'Anki 导入';
    if (targetDeckName == null) {
      final nonDefault = deckNames.values.where((n) => n != 'Default' && n.isNotEmpty);
      if (nonDefault.isNotEmpty) {
        rootDeckName = nonDefault.first.split('::').first;
      }
    }
    final rootDeck = await _ensureDeck(rootDeckName);
    for (final did in deckNames.keys) {
      deckIdMap[did] = rootDeck.id;
    }

    final noteRows = db.select('SELECT id, guid, mid, tags, flds FROM notes');
    final cardRows = db.select(
        'SELECT id, nid, did, queue, due, ivl, factor, reps, lapses FROM cards');

    final cardsByNote = <String, List<Map<String, Object?>>>{};
    for (final c in cardRows) {
      final nid = c['nid'].toString();
      cardsByNote.putIfAbsent(nid, () => []).add(c);
    }

    var noteCount = 0, cardCount = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final n in noteRows) {
      final nid = n['id'].toString();
      final mid = n['mid'].toString();
      final fldsRaw = (n['flds'] as String?) ?? '';
      final fieldVals = fldsRaw.split(_fldSep);
      final tagsRaw = (n['tags'] as String?) ?? '';
      final tags = tagsRaw.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      final noteId = newId();
      await repo.db.into(repo.db.notes).insert(NotesCompanion.insert(
            id: noteId,
            noteTypeId: typeMapping[mid] ?? basic.id,
            fields: jsonEncode(fieldVals),
            tags: Value(tags.join(' ')),
            guid: (n['guid'] as String?) ?? newId(),
            version: now,
          ));
      noteCount++;

      final cs = cardsByNote[nid] ?? const <Map<String, Object?>>[];
      if (cs.isEmpty) continue;
      for (var ord = 0; ord < cs.length; ord++) {
        final c = cs[ord];
        final queue = (c['queue'] as int?) ?? 0;
        final ivlDays = ((c['ivl'] as int?) ?? 0).toDouble();
        final dueAnki = (c['due'] as int?) ?? 0;
        final factor = ((c['factor'] as int?) ?? 2500) / 1000.0;

        int ourQueue;
        int dueMs;
        if (queue == -1) {
          ourQueue = Queue.suspended;
          dueMs = 0;
        } else if (queue == 0) {
          ourQueue = Queue.newCard;
          dueMs = 0;
        } else if (queue == 1 || queue == 3) {
          ourQueue = Queue.learning;
          dueMs = dueAnki * 1000; // 学习队列的 due 是秒级时间戳
        } else {
          ourQueue = Queue.review;
          final today = DateTime.now();
          final startOfToday =
              DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
          dueMs = startOfToday + Duration(days: ivlDays.floor()).inMilliseconds;
        }

        final stability = ivlDays >= 1 ? ivlDays : 0.0;
        final difficulty = (5.0 - (factor - 2.5) * 2.0).clamp(1.0, 10.0);

        await repo.db.into(repo.db.cards).insert(CardsCompanion.insert(
              id: newId(),
              noteId: noteId,
              deckId: deckIdMap[(c['did'] as int?).toString()] ?? rootDeck.id,
              templateIndex: Value(ord),
              queue: Value(ourQueue),
              due: Value(dueMs),
              stability: Value(stability),
              difficulty: Value(stability > 0 ? difficulty : 0.0),
              stabilityFast: Value(stability),
              reps: Value((c['reps'] as int?) ?? 0),
              lapses: Value((c['lapses'] as int?) ?? 0),
              lastReview: Value(stability > 0 ? now : 0),
              version: now,
            ));
        cardCount++;
      }
    }

    return ApkgImportResult(
      decks: 1,
      notes: noteCount,
      cards: cardCount,
      skippedNoteTypes: skippedTypes,
      message: '已导入到牌组「${rootDeck.name}」',
    );
  }

  bool _isClozeModel(Map<String, dynamic> model) {
    final t = model['type'];
    if (t is int && t == 1) return true;
    final tmpls = (model['tmpls'] as List?) ?? const [];
    for (final tmpl in tmpls) {
      final qfmt = ((tmpl as Map)['qfmt'] as String?) ?? '';
      if (qfmt.contains('{{c')) return true;
    }
    return false;
  }

  Future<Deck> _ensureDeck(String name) async {
    // 用 .get() 而非 getSingleOrNull():牌组名可重复(同名分组可共存),
    // 多行时 getSingleOrNull 会抛 "Too many elements"。取第一个匹配即可。
    final existing = await (repo.db.select(repo.db.decks)
          ..where((t) => t.deleted.equals(false) & t.name.equals(name)))
        .get();
    if (existing.isNotEmpty) return existing.first;
    return repo.createDeck(name);
  }
}

/// APKG 导入异常（带用户可读信息）。
class ApkgImportException implements Exception {
  ApkgImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
