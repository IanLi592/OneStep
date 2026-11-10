import 'collection_repo.dart';
import 'xlsx_importer.dart';

/// XLSX 导入结果。
class XlsxImportResult {
  const XlsxImportResult({
    required this.rows,
    required this.decksCreated,
    required this.decksReused,
    required this.cardsCreated,
    this.maxDepthReached = 0,
    this.rejectedPaths = const [],
    this.importedPaths = const [],
  });

  final int rows;
  final int decksCreated;
  final int decksReused;
  final int cardsCreated;

  /// 本次实际用到的最深层数。
  final int maxDepthReached;

  /// 超过深度上限、导致整批被拒的路径**原文**（非空时 cardsCreated 必为 0）。
  ///
  /// 用源分隔符 `::` 拼接（各段已 trim），因为这条是拿去 xlsx 里搜、改完重导的；
  /// 与 [importedPaths] 的 ` › ` 展示形式**故意不一样**。
  final List<String> rejectedPaths;

  /// 成功导入的完整路径（去重、保序），用于给用户回显"卡到底去哪了"。
  /// 展示形式，段间是 ` › `；要拿回去文件里对照的字段是 [rejectedPaths]。
  final List<String> importedPaths;

  bool get aborted => rejectedPaths.isNotEmpty;
}

/// 把解析出的 XLSX 行写入数据库：按**层级路径**建/复用分组，逐行建卡。
///
/// 层级来源有两处，优先级从高到低：
///  1. 单元格里的 `::` 路径（Anki 兼容写法）：`大模型::深度学习` 直接分层；
///  2. 闪记盒导出的**文件名**：它按叶子分组逐个导出，父路径只出现在文件名里
///     （实测 `大模型-英文缩写-2026-11-02_10_03_10.xlsx` 的牌组列只有 `英文缩写`）。
///     仅当"文件名末段 == 单元格牌组名"时才采信，避免把含 `-` 的组名切错。
///
/// 单元格为空时归入 [fallbackDeckName]。
class XlsxImportService {
  XlsxImportService(this.repo);

  final CollectionRepo repo;

  /// 尾部时间戳：`-2026-11-02_10_03_10`。日期本身含 `-`，所以整段锚定匹配。
  static final RegExp _tsSuffix =
      RegExp(r'-\d{4}-\d{2}-\d{2}(_\d{2}_\d{2}_\d{2})?$');

  /// 从 .xlsx 字节导入。返回统计。
  ///
  /// [sourceFileName] 传入原始文件名（含或不含扩展名均可）时可启用
  /// 闪记盒式的"文件名推父路径"。
  Future<XlsxImportResult> importBytes(
    List<int> bytes, {
    String? sourceFileName,
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

    final fromFile = _pathFromFileName(sourceFileName);

    // ---- 第一遍：只算路径、只做校验，不写库 ----
    final paths = <List<String>>[];
    final rejected = <String>[];
    for (final row in rows) {
      final segments = _resolvePath(row, fromFile, fallbackDeckName);
      if (segments.length > kMaxDeckDepth) {
        // 必须是**源分隔符** `::` 形式，不能用展示串的 ` › `：这条的唯一用途就是
        // 让用户回到 xlsx 里把那一行找出来改掉。展示格式是 UI 的事，不是数据层的。
        final raw = joinDeckPath(segments, separator: kDeckPathSeparator);
        if (!rejected.contains(raw)) rejected.add(raw);
        continue;
      }
      paths.add(segments);
    }

    // D4：超深就整批中止。静默截断会让用户事后找不到卡片去哪了，比导不进去更糟。
    if (rejected.isNotEmpty) {
      return XlsxImportResult(
        rows: rows.length,
        decksCreated: 0,
        decksReused: 0,
        cardsCreated: 0,
        rejectedPaths: rejected,
      );
    }

    // ---- 第二遍：逐级建组（同父重名复用）+ 建卡 ----
    final existing = await repo.liveDecks();
    final existingLive = liveIds(existing);
    final childIndex = <String, Map<String, String>>{}; // 父id(''=顶层) -> {名: id}
    for (final d in existing) {
      // 与树/下拉框同一口径：父不存在就当顶层，否则同名的孤儿组找不到、
      // 会被当成"没有这个组"再建一个。
      final key = effectiveParent(existingLive, d) ?? '';
      (childIndex[key] ??= {})[d.name] = d.id;
    }

    var decksCreated = 0;

    /// 复用只统计**导入前就存在**的分组，且按 id 去重。
    ///
    /// 两处都会虚高：① 原来每行每段各 +1，320 行挂同一条 3 层路径就报"复用
    /// 960 个分组"；② 本次刚建的组被后面的行路过时也不算复用，否则"新建 1 个、
    /// 复用 3 个"里那个 3 是自家人，用户读不出到底省下了什么。
    final preExisting = {for (final d in existing) d.id};
    final reusedDeckIds = <String>{};
    var maxDepth = 0;
    final importedPaths = <String>[];

    Future<String?> ensureChain(List<String> segments) async {
      String? parentId;
      for (final name in segments) {
        final key = parentId ?? '';
        final known = childIndex[key]?[name];
        if (known != null) {
          if (preExisting.contains(known)) reusedDeckIds.add(known);
          parentId = known;
          continue;
        }
        final created =
            await repo.createDeck(name, parentId: parentId, reuseOnConflict: true);
        (childIndex[key] ??= {})[name] = created.id;
        decksCreated++;
        parentId = created.id;
      }
      return parentId;
    }

    var cardsCreated = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final segments = paths[i];

      // 先定内容再建组：正面必填，背面可为空（仍建卡）。
      // 顺序很要紧——早先是先 ensureChain 再判空，于是"正面背面都空"的行会在树上
      // 留下一个永远空的空壳分组，用户只看到多出来的组、看不到卡片，以为导入丢东西。
      final front = row.front.isNotEmpty ? row.front : row.back;
      final back = row.front.isNotEmpty ? row.back : '';
      if (front.isEmpty) continue;

      final leafDeckId = await ensureChain(segments);
      if (leafDeckId == null) continue;

      final label = joinDeckPath(segments);
      if (!importedPaths.contains(label)) importedPaths.add(label);
      if (segments.length > maxDepth) maxDepth = segments.length;

      await repo.createBasicNote(deckId: leafDeckId, front: front, back: back);
      cardsCreated++;
    }

    return XlsxImportResult(
      rows: rows.length,
      decksCreated: decksCreated,
      decksReused: reusedDeckIds.length,
      cardsCreated: cardsCreated,
      maxDepthReached: maxDepth,
      importedPaths: importedPaths,
    );
  }

  /// 单行 -> 层级路径段。
  ///
  /// [fromFile] 是从文件名解析出的**完整路径（含叶子）**，可能为空。
  List<String> _resolvePath(
    XlsxRow row,
    List<String> fromFile,
    String fallbackDeckName,
  ) {
    final cell = splitDeckPath(row.deck);
    if (cell.isEmpty) {
      // 牌组列为空：有文件名路径就用它，否则归入兜底名。
      return fromFile.isNotEmpty ? fromFile : [fallbackDeckName];
    }
    if (cell.length > 1) return cell; // 单元格自带 :: 路径，优先，不看文件名
    // 单元格是单层名：只有当"文件名路径的末段正好等于它"时才采信文件名路径
    // （文件名路径已含叶子，直接用，不再拼接）。否则不猜，避免把含 - 的
    // 组名切错。
    if (fromFile.length > 1 && fromFile.last == cell.first) return fromFile;
    return cell;
  }

  /// 从闪记盒导出文件名推出完整路径（**含叶子**）。
  ///
  /// `大模型-英文缩写-2026-11-02_10_03_10.xlsx` -> `[大模型, 英文缩写]`。
  /// 认不出时间戳的文件名返回空（不猜）。
  static List<String> _pathFromFileName(String? name) {
    if (name == null || name.isEmpty) return const [];
    var stem = name;
    // 只按已知扩展名剥，且容忍双点（实测文件名是 `..._10_03_10..xlsx`）。
    stem = stem.replaceFirst(RegExp(r'\.(xlsx|xls|csv)$', caseSensitive: false), '');
    stem = stem.replaceAll(RegExp(r'[.\s]+$'), '');
    if (!_tsSuffix.hasMatch(stem)) return const [];
    stem = stem.replaceAll(_tsSuffix, '');
    final parts = stem
        .split('-')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.length >= 2 ? parts : const [];
  }
}
