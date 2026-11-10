import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/deck_tree.dart';

/// 纯树函数单测：不碰数据库，所以边界条件（成环的脏数据、孤儿、超深）
/// 都能直接构造出来跑。
void main() {
  Deck d(String id, String name, {String? parent}) =>
      Deck(id: id, name: name, parentId: parent, deleted: false, version: 1);

  DeckCounts c({int n = 0, int l = 0, int r = 0, int total = 0, int studied = 0}) =>
      DeckCounts(
          newCards: n,
          learning: l,
          review: r,
          totalCards: total,
          studiedCards: studied);

  group('splitDeckPath', () {
    test('按 :: 切成段', () {
      expect(splitDeckPath('大模型::深度学习::卷积'), ['大模型', '深度学习', '卷积']);
    });

    test('trim 每段并丢弃空段', () {
      expect(splitDeckPath(' A :: B '), ['A', 'B']);
      expect(splitDeckPath('A::::B'), ['A', 'B'], reason: '连续分隔符不该产生空层');
      expect(splitDeckPath(''), isEmpty);
      expect(splitDeckPath('::'), isEmpty);
    });

    test('无分隔符时就是单段（旧文件向后兼容）', () {
      expect(splitDeckPath('英文缩写'), ['英文缩写']);
    });

    test('段数即深度，供超深判定', () {
      expect(splitDeckPath('1::2::3::4::5').length, kMaxDeckDepth);
      expect(splitDeckPath('1::2::3::4::5::6').length, greaterThan(kMaxDeckDepth));
    });
  });

  group('树构建', () {
    test('depthOf / chainOf 给出根到自身的路径', () {
      final decks = [d('a', 'A'), d('b', 'B', parent: 'a'), d('c', 'C', parent: 'b')];
      expect(chainOf(decks, 'c').map((e) => e.name), ['A', 'B', 'C']);
      expect(depthOf(decks, 'c'), 3);
      expect(depthOf(decks, 'a'), 1);
    });

    test('descendantIds 不含自身', () {
      final decks = [d('a', 'A'), d('b', 'B', parent: 'a'), d('c', 'C', parent: 'b')];
      expect(descendantIds(decks, 'a'), {'b', 'c'});
      expect(descendantIds(decks, 'c'), isEmpty);
    });

    test('脏数据成环时遍历能停下（不挂死）', () {
      // 手写库/同步冲突可能造出 a->b->a。这里只要求"能返回"，
      // 环上节点互相算作后代是可接受的（deleteDeck 会一并软删，不会漏）。
      final decks = [d('a', 'A', parent: 'b'), d('b', 'B', parent: 'a')];
      expect(descendantIds(decks, 'a'), isNotEmpty, reason: '能返回即证明没挂死');
      expect(subtreeIds(decks, 'a'), containsAll(['a', 'b']));
      expect(maxSubtreeDepth(decks, 'a'), greaterThanOrEqualTo(2));
    });

    test('孤儿（父不存在）按顶层排', () {
      final decks = [d('o', '孤儿', parent: '不存在'), d('r', '正常根')];
      final tree = buildTree(decks, {});
      expect(tree.map((n) => n.name).toSet(), {'孤儿', '正常根'});
      expect(tree.firstWhere((n) => n.name == '孤儿').depth, 1);
    });

    test('forestPreOrder 与 buildTree 是同一批分组（孤儿不许从下拉框消失）', () {
      // allDecks() 走 forestPreOrder，首页树走 buildTree。曾经 buildTree 把孤儿
      // 提到顶层、childrenIndex 却按字面 parentId 归堆，于是同步期"子先到、父还
      // 没到"的分组在首页能看到、在添加卡片/浏览页的分组下拉里选不到。
      final decks = [
        d('r', '正常根'),
        d('o', '孤儿', parent: '还没同步到的父'),
        d('oc', '孤儿的子', parent: 'o'),
      ];
      final flat = forestPreOrder(decks);
      expect(flat.length, decks.length, reason: '一个都不能少');
      expect(flat.map((e) => e.id).toList(), ['o', 'oc', 'r'],
          reason: '孤儿按顶层排（id 升序），它的子仍紧跟其后');

      Set<String> ids(List<DeckNode> ns) =>
          {for (final n in ns) ...[n.id, ...ids(n.children)]};
      expect(ids(buildTree(decks, {})), flat.map((e) => e.id).toSet(),
          reason: '两个口径必须给同一批分组');
    });

    test('buildTree 自底向上聚合，每张卡只算一次', () {
      final decks = [
        d('root', '根'),
        d('c1', '子1', parent: 'root'),
        d('c2', '子2', parent: 'root'),
        d('g1', '孙1', parent: 'c1'),
      ];
      final per = {
        'root': c(n: 1, total: 1),
        'c1': c(n: 2, total: 2),
        'c2': c(n: 3, total: 3),
        'g1': c(n: 4, total: 4),
      };
      final tree = buildTree(decks, per);
      final root = tree.single;
      expect(root.counts.newCards, 10, reason: '1+2+3+4，孙只经 c1 汇入一次');
      expect(root.children.map((n) => n.name), ['子1', '子2']);
      expect(root.children.first.counts.newCards, 6, reason: 'c1 含其孙 g1');
    });

    test('同级按创建顺序（id 升序），不是按名字码位', () {
      final decks = [d('1', 'zzz'), d('2', 'aaa'), d('3', 'mmm')];
      expect(forestPreOrder(decks).map((e) => e.name), ['zzz', 'aaa', 'mmm']);
    });

    test('canAddChild 到第 5 层为 false', () {
      final decks = [
        d('l1', 'L1'),
        d('l2', 'L2', parent: 'l1'),
        d('l3', 'L3', parent: 'l2'),
        d('l4', 'L4', parent: 'l3'),
        d('l5', 'L5', parent: 'l4'),
      ];
      final tree = buildTree(decks, {});
      final l5 = tree.single.children.single.children.single.children.single.children.single;
      expect(l5.name, 'L5');
      expect(l5.depth, kMaxDeckDepth);
      expect(l5.canAddChild, isFalse);
      expect(l5.children, isEmpty);
      expect(tree.single.children.single.children.single.children.single.canAddChild, isTrue,
          reason: '第 4 层还能再建一层');
    });
  });

  group('subtreeCount', () {
    test('父分组统计包含整棵子树', () {
      final decks = [d('p', '父'), d('k', '子', parent: 'p')];
      final per = {'p': c(n: 1, total: 1), 'k': c(n: 2, total: 2)};
      final agg = subtreeCount(decks, per, 'p');
      expect(agg.newCards, 3);
      expect(agg.totalCards, 3);
      expect(subtreeCount(decks, per, 'k').totalCards, 2, reason: '叶子只算自己');
    });

    test('空分组计数为 0 且 progress 不除零', () {
      expect(DeckCounts.zero.total, 0);
      expect(DeckCounts.zero.progress, 0);
    });
  });

  group('flattenVisible', () {
    final decks = [
      d('a', 'A'),
      d('a1', 'A1', parent: 'a'),
      d('a11', 'A11', parent: 'a1'),
      d('b', 'B'),
    ];

    test('默认全展开时按前序摊平', () {
      final flat = flattenVisible(buildTree(decks, {}), {});
      expect(flat.map((n) => n.name), ['A', 'A1', 'A11', 'B']);
      expect(flat.map((n) => n.depth), [1, 2, 3, 1]);
    });

    test('折叠中间层只隐藏其后代，兄弟树不受影响', () {
      final flat = flattenVisible(buildTree(decks, {}), {'a1'});
      expect(flat.map((n) => n.name), ['A', 'A1', 'B']);
    });

    test('折叠根节点只剩根自己', () {
      final flat = flattenVisible(buildTree(decks, {}), {'a'});
      expect(flat.map((n) => n.name), ['A', 'B']);
    });

    test('subtreeDeckCount 供删除前报影响面', () {
      final tree = buildTree(decks, {});
      final a = tree.firstWhere((n) => n.name == 'A');
      expect(a.subtreeDeckCount, 3);
      expect(a.subtreeDeckCount - 1, 2, reason: '子分组数不含自身');
    });
  });

  test('异常文案可直接给用户看', () {
    expect(DeckDepthException(5).toString(), contains('5 层'));
    expect(DeckNameConflictException('算法', parentName: '大模型').toString(),
        allOf(contains('大模型'), contains('算法')));
    expect(DeckCycleException('父', '子').toString(), contains('循环'));
  });
}
