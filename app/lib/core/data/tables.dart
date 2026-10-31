import 'package:drift/drift.dart';

/// SQLite 数据表定义（Drift）。
///
/// 数据模型借鉴 Anki 的经典结构（牌组/笔记类型/笔记/卡片/复习日志），
/// 但为干净重实现，并为每条记录附加同步元数据（version 用于 LWW 合并）。
///
/// 表名使用 snake_case 复数。

// ---------------------------------------------------------------------------
// 牌组
// ---------------------------------------------------------------------------
class Decks extends Table {
  TextColumn get id => text()();
  /// 牌组名（同一父级下唯一）。
  TextColumn get name => text()();
  /// 父牌组 id，null 表示顶层牌组（支持嵌套）。
  TextColumn get parentId => text().nullable()();
  /// 是否已删除（软删除，便于同步传播删除）。
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  /// 同步用：毫秒时间戳，最后写入者胜出。
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// 笔记类型（模板）
// ---------------------------------------------------------------------------
class NoteTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  /// 字段名列表，JSON 数组字符串，如 ["正面","背面"]。
  TextColumn get fields => text()();
  /// 卡片模板列表，JSON 数组字符串。普通类型一项 {q,a}；完形填空按 c1..cn。
  TextColumn get templates => text()();
  /// 卡片展示 CSS。
  TextColumn get css => text().withDefault(const Constant(''))();
  /// 是否为完形填空类型。
  BoolColumn get isCloze => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// 笔记
// ---------------------------------------------------------------------------
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get noteTypeId => text()();
  /// 字段值列表，JSON 数组字符串，顺序与 NoteTypes.fields 对齐。
  TextColumn get fields => text()();
  /// 标签，空格分隔字符串。
  TextColumn get tags => text().withDefault(const Constant(''))();
  /// 全局唯一 id（导入/去重用，仿 Anki guid）。
  TextColumn get guid => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// 卡片（含调度状态）
// ---------------------------------------------------------------------------

/// 卡片队列状态：
/// 0=新卡(new) 1=学习中(learning) 2=复习(review) 3=重学(relearning) -1=已挂起(suspended)
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  /// 卡片所属牌组。
  TextColumn get deckId => text()();
  /// 该笔记生成的第几张卡片（模板下标）。
  IntColumn get templateIndex => integer().withDefault(const Constant(0))();

  // ---- 调度状态（FSRS）----
  IntColumn get queue => integer().withDefault(const Constant(0))();
  /// 到期时间（毫秒时间戳）。新卡=尚未安排。
  IntColumn get due => integer().withDefault(const Constant(0))();
  RealColumn get stability => real().withDefault(const Constant(0.0))();
  RealColumn get difficulty => real().withDefault(const Constant(0.0))();
  RealColumn get stabilityFast => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  /// 上次复习时间（毫秒时间戳），0 表示从未复习。
  IntColumn get lastReview => integer().withDefault(const Constant(0))();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// 复习日志（供统计 + 撤销 + 同步）
// ---------------------------------------------------------------------------
class ReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text()();
  /// 评分 1..4。
  IntColumn get rating => integer()();
  /// 复习时间（毫秒时间戳）。
  IntColumn get reviewedAt => integer()();
  /// 作答耗时（毫秒）。
  IntColumn get takenMs => integer().withDefault(const Constant(0))();
  /// 复习前的间隔（天）。
  RealColumn get intervalBefore => real().withDefault(const Constant(0.0))();
  /// 复习后的间隔（天）。
  RealColumn get intervalAfter => real().withDefault(const Constant(0.0))();
  /// 是否被撤销（撤销的复习不计入统计）。
  BoolColumn get undone => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// 集合配置（设置项 + 同步游标）
// ---------------------------------------------------------------------------
class CollectionConfigs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}
