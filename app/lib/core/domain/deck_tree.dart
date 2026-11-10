/// 分组层级：树结构、深度上限、校验异常、聚合计数。
///
/// 这里刻意只放**纯函数**（输入扁平的 decks 列表，输出树/深度/后代集合），
/// 不碰数据库，所以单测不需要 Drift 就能把边界条件全跑一遍。
/// 真正读写库的方法在 CollectionRepo 里，它们调用本文件的函数。
library;

import '../data/database.dart';

/// 分组最多 5 层（根分组 = 第 1 层）。
const int kMaxDeckDepth = 5;

/// 路径分隔符：与 Anki 一致，便于从 Anki/其它工具迁移。
const String kDeckPathSeparator = '::';

// ---------------------------------------------------------------------------
// 类型化异常（UI 直接展示 message，不再打原始字符串）
// ---------------------------------------------------------------------------

/// 超过深度上限。
class DeckDepthException implements Exception {
  DeckDepthException(this.parentDepth, [this.maxDepth = kMaxDeckDepth]);

  /// 父分组所在层数（父为 null 时按 0 计）。
  final int parentDepth;
  final int maxDepth;

  @override
  String toString() => '分组最多 $maxDepth 层：父分组已在第 $parentDepth 层，'
      '再建就会到第 ${parentDepth + 1} 层。';
}

/// 同一父分组下名字重复。
class DeckNameConflictException implements Exception {
  DeckNameConflictException(this.name, {this.parentName});

  final String name;
  final String? parentName;

  @override
  String toString() => parentName == null
      ? '顶层已有名为「$name」的分组。'
      : '「$parentName」下已有名为「$name」的分组。';
}

/// 把分组挂到自己或自己的后代下（会形成环）。
class DeckCycleException implements Exception {
  DeckCycleException(this.deckName, this.targetName);

  final String deckName;
  final String targetName;

  @override
  String toString() => '不能把「$deckName」移动到它自己或它的子分组「$targetName」下面，'
      '那样会形成循环。';
}

// ---------------------------------------------------------------------------
// 聚合计数
// ---------------------------------------------------------------------------

/// 牌组今日计数 + 总数/已学。
///
/// 层级化之后这里的口径是**整棵子树**（每张卡只计一次），
/// 由 [rollUpCounts] 自底向上累加得出。
class DeckCounts {
  const DeckCounts({
    required this.newCards,
    required this.learning,
    required this.review,
    this.totalCards = 0,
    this.studiedCards = 0,
  });

  final int newCards;
  final int learning;
  final int review;

  /// 牌组内卡片总数（进度条分母）。
  final int totalCards;

  /// 已学过（非新卡）数量（进度条分子）。
  final int studiedCards;

  /// 今日待处理（新 + 到期学习/复习）。
  int get total => newCards + learning + review;

  /// 学习进度 0.0~1.0。
  double get progress => totalCards == 0 ? 0 : studiedCards / totalCards;

  static const DeckCounts zero =
      DeckCounts(newCards: 0, learning: 0, review: 0);

  DeckCounts operator +(DeckCounts o) => DeckCounts(
        newCards: newCards + o.newCards,
        learning: learning + o.learning,
        review: review + o.review,
        totalCards: totalCards + o.totalCards,
        studiedCards: studiedCards + o.studiedCards,
      );
}

// ---------------------------------------------------------------------------
// 纯树操作
// ---------------------------------------------------------------------------

/// 按 (有效父 id, name) 分组的子表。顶层（含孤儿）挂在虚拟根 `''` 下。
///
/// 同级排序用 **id 升序**而不是名字：`newId()` 是时间戳前缀，所以 id 升序
/// 就是创建顺序，且改名/移动都不会让分组在列表里乱跳。
/// 名字排序对中文也不合适——Dart 的 compareTo 按 UTF-16 码位，
/// `英语单词`(U+82F1) 会排到 `默认牌组`(U+9ED8) 前面，不是拼音序。
Map<String, List<Deck>> childrenIndex(List<Deck> decks) {
  final live = liveIds(decks);
  final map = <String, List<Deck>>{};
  for (final d in decks) {
    final key = effectiveParent(live, d) ?? '';
    (map[key] ??= []).add(d);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.id.compareTo(b.id));
  }
  return map;
}

/// 未删除分组的 id 集合（判断"父还在不在"用）。
Set<String> liveIds(List<Deck> decks) => decks.map((d) => d.id).toSet();

/// 有效父 id：父不存在（未同步到 / 已删）则视为顶层，返回 null。
///
/// 孤儿**必须**按顶层呈现：同步期"子先到、父还没到"是常态，把孤儿藏起来等于
/// 凭空少一个分组。这里曾经是两套口径——[buildTree] 提升孤儿、[childrenIndex]
/// 不提升，于是同一个组在首页能看到、在 `allDecks()` 的下拉框里选不到。
/// 现在 [childrenIndex] 与 [buildTree] 都只走这一个函数。
String? effectiveParent(Set<String> live, Deck d) =>
    effectiveParentId(live, d.parentId);

/// 同上，但入参是**父 id 本身**（新建/移动时手上只有 id，没有 Deck 行）。
///
/// 重名/同父判定必须用它：直接比 `d.parentId ?? ''` 会把"真顶层"和"父已删的
/// 孤儿"当成两个不同的桶，于是顶层能长出两个同名兄弟。
String? effectiveParentId(Set<String> live, String? parentId) {
  if (parentId == null) return null;
  return live.contains(parentId) ? parentId : null;
}

/// 自根到该分组的链（含自身）。带 visited 保护，脏数据成环也不会死循环。
List<Deck> chainOf(List<Deck> decks, String deckId) {
  final byId = {for (final d in decks) d.id: d};
  final chain = <Deck>[];
  final seen = <String>{};
  var cur = byId[deckId];
  while (cur != null && seen.add(cur.id)) {
    chain.insert(0, cur);
    final p = cur.parentId;
    cur = (p == null) ? null : byId[p];
  }
  return chain;
}

/// 分组深度（根 = 1）。
int depthOf(List<Deck> decks, String deckId) => chainOf(decks, deckId).length;

/// 某分组的全部后代 id（不含自身）。
Set<String> descendantIds(List<Deck> decks, String deckId) {
  final kids = childrenIndex(decks);
  final out = <String>{};
  final stack = <String>[deckId];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    for (final c in (kids[cur] ?? const [])) {
      if (out.add(c.id)) stack.add(c.id);
    }
  }
  return out;
}

/// 把 [separator] 分隔的路径原文切成段：trim、丢空段。
///
/// `'A::B::C'` -> `[A, B, C]`；`'A::::B'` -> `[A, B]`；`''` -> `[]`。
List<String> splitDeckPath(String raw, {String separator = kDeckPathSeparator}) {
  return raw
      .split(separator)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// 把"父路径 + 叶子名"拼成展示用的完整路径。
String joinDeckPath(List<String> segments, {String separator = ' › '}) =>
    segments.join(separator);

/// 按 id 取分组。
Deck? byId(List<Deck> decks, String id) {
  for (final d in decks) {
    if (d.id == id) return d;
  }
  return null;
}

/// 某分组"自身 + 全部后代"的 id 集合（含自身）。
Set<String> subtreeIds(List<Deck> decks, String deckId) =>
    {deckId, ...descendantIds(decks, deckId)};

/// 子树最大深度（自身算 1）。用于"移动整棵子树后最深点是否超限"。
///
/// 带 seen 守卫：手写库或同步冲突可能造出 `a->b->a` 的环，
/// 没有守卫这里会无限递归爆栈（被 deck_tree_test 的成环用例抓到）。
int maxSubtreeDepth(List<Deck> decks, String deckId) {
  final kids = childrenIndex(decks);
  final seen = <String>{deckId};
  int walk(String id, int depth) {
    var max = depth;
    for (final c in (kids[id] ?? const [])) {
      if (!seen.add(c.id)) continue; // 已经走过 = 成环，停止下钻
      final d = walk(c.id, depth + 1);
      if (d > max) max = d;
    }
    return max;
  }
  return walk(deckId, 1);
}

/// 前序遍历（父在前、同级按 id=创建顺序）——首页列表与 allDecks 的展示顺序。
///
/// 与 [buildTree] 用同一张 [childrenIndex]，所以"树里能看到的分组"和
/// "allDecks 返回的分组"是同一批，孤儿不会再从下拉框里静默消失。
List<Deck> forestPreOrder(List<Deck> decks) {
  final out = <Deck>[];
  final kids = childrenIndex(decks);
  final roots = kids[''] ?? const <Deck>[];
  void walk(Deck d) {
    out.add(d);
    for (final c in (kids[d.id] ?? const [])) {
      walk(c);
    }
  }
  for (final r in roots) {
    walk(r);
  }
  return out;
}

/// 树节点（[deck] + 深度 + 子节点 + **子树聚合**计数）。
class DeckNode {
  const DeckNode({
    required this.deck,
    required this.depth,
    required this.children,
    required this.counts,
  });

  final Deck deck;

  /// 根 = 1。
  final int depth;
  final List<DeckNode> children;

  /// 整棵子树的计数（每张卡只算一次）。
  final DeckCounts counts;

  String get name => deck.name;
  String get id => deck.id;
  bool get isLeaf => children.isEmpty;
  bool get canAddChild => depth < kMaxDeckDepth;

  /// 子树里的分组总数（含自身），用于删除前如实报影响面。
  int get subtreeDeckCount =>
      1 + children.fold<int>(0, (a, c) => a + c.subtreeDeckCount);
}

/// 由"每个分组自己的计数"自底向上算出某分组子树的合计。
DeckCounts subtreeCount(
  List<Deck> decks,
  Map<String, DeckCounts> perDeck,
  String deckId,
) {
  var total = perDeck[deckId] ?? DeckCounts.zero;
  for (final id in descendantIds(decks, deckId)) {
    total = total + (perDeck[id] ?? DeckCounts.zero);
  }
  return total;
}

/// 按折叠状态把森林摊平成"可见的行"（前序，跳过被折叠节点的子树）。
///
/// 单独做成纯函数是为了能单测折叠逻辑——UI 里只负责按 [DeckNode.depth] 缩进。
List<DeckNode> flattenVisible(List<DeckNode> nodes, Set<String> collapsed) {
  final out = <DeckNode>[];
  void walk(List<DeckNode> level) {
    for (final n in level) {
      out.add(n);
      if (n.children.isNotEmpty && !collapsed.contains(n.id)) walk(n.children);
    }
  }
  walk(nodes);
  return out;
}

/// 构建森林（根按创建顺序），每个节点带子树聚合计数与深度。
List<DeckNode> buildTree(List<Deck> decks, Map<String, DeckCounts> perDeck) {
  // 归堆口径完全交给 childrenIndex（孤儿提升为顶层），这里不再自己算一遍，
  // 否则又会退回"首页有、下拉框没有"的双口径。
  final childKey = childrenIndex(decks);

  DeckNode build(Deck d, int depth) {
    final children = [
      for (final c in (childKey[d.id] ?? const <Deck>[])) build(c, depth + 1),
    ];
    return DeckNode(
      deck: d,
      depth: depth,
      children: children,
      counts: children.fold<DeckCounts>(
        perDeck[d.id] ?? DeckCounts.zero,
        (acc, c) => acc + c.counts,
      ),
    );
  }

  return [
    for (final r in (childKey[''] ?? const <Deck>[])) build(r, 1),
  ];
}
