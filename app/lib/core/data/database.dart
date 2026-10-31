import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// 应用数据库（Drift / SQLite）。
///
/// 单文件存储，本地优先。所有表见 tables.dart。
@DriftDatabase(tables: [Decks, NoteTypes, Notes, Cards, ReviewLogs, CollectionConfigs])
class OnestepDb extends _$OnestepDb {
  OnestepDb(super.e);

  @override
  int get schemaVersion => 1;

  /// 在应用启动时调用：创建默认牌组与默认笔记类型。
  Future<void> seedDefaults() async {
    final existingDeck =
        await (select(decks)..where((t) => t.deleted.equals(false))).getSingleOrNull();
    if (existingDeck == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(decks).insert(DecksCompanion.insert(
        id: newId(),
        name: '默认牌组',
        parentId: const Value(null),
        version: now,
      ));
    }
    final existingType =
        await (select(noteTypes)..where((t) => t.deleted.equals(false))).getSingleOrNull();
    if (existingType == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(noteTypes).insert(NoteTypesCompanion.insert(
        id: newId(),
        name: '基本（正面/背面）',
        fields: '["正面","背面"]',
        templates: '[{"name":"卡片 1","qfmt":"{{正面}}","afmt":"{{FrontSide}}<hr id=answer>{{背面}}"}]',
        isCloze: const Value(false),
        version: now,
      ));
    }
  }
}

/// 单调递增计数器，保证同一微秒内连续调用也得到不同 id。
int _seq = 0;

/// 生成一个唯一的字符串 id（时间戳 + 序号 + 随机），用于所有实体主键。
///
/// 用单调序号避免同一微秒内碰撞（批量导入时连续调用会落在同一微秒）。
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch;
  final seq = (_seq = (_seq + 1) & 0xffff);
  final r = _randomHex(6);
  return '${t.toRadixString(36)}-${seq.toRadixString(36)}-$r';
}

String _randomHex(int n) {
  const chars = '0123456789abcdef';
  final now = DateTime.now().microsecondsSinceEpoch;
  var x = (now ^ (now >> 33) ^ (_seq * 2654435761)) & 0xffffffff;
  final buf = StringBuffer();
  for (var i = 0; i < n; i++) {
    x ^= (x << 13) & 0xffffffff;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xffffffff;
    buf.write(chars[(x.abs()) % 16]);
  }
  return buf.toString();
}

/// 打开应用数据库。数据库文件放在应用文档目录下。
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'onestep.db'));
    return NativeDatabase.createInBackground(file);
  });
}
