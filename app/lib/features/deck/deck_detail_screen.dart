import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' show Deck;
import '../../core/domain/browser_service.dart';
import '../../core/domain/collection_repo.dart' show Queue, CollectionRepo;
import '../../core/domain/deck_tree.dart';
import '../../core/domain/providers.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';
import '../card_edit/add_card_sheet.dart';
import '../review/review_screen.dart';

/// 牌组内卡片(供网格展示)。按筛选条件加载。
final _deckCardsProvider =
    FutureProvider.autoDispose.family<List<BrowseItem>, String>((ref, deckId) async {
  final db = ref.watch(dbProvider);
  return BrowserService(db).search(CardQuery(deckId: deckId));
});

/// 卡片筛选页签。
enum DeckFilter { all, newOnly, learning }

/// 面包屑：根 -> 当前分组（要能点，所以取分组对象而非只有名字）。
final _deckChainProvider =
    FutureProvider.autoDispose.family<List<Deck>, String>((ref, deckId) async {
  return ref.watch(repoProvider).deckChain(deckId);
});

/// 牌组详情页:封面头卡 + 统计 + 开始记忆 + 筛选标签 + 2 列卡片网格。
class DeckDetailScreen extends ConsumerStatefulWidget {
  const DeckDetailScreen({super.key, required this.deckId, required this.deckName});

  final String deckId;
  final String deckName;

  @override
  ConsumerState<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends ConsumerState<DeckDetailScreen> {
  DeckFilter _filter = DeckFilter.all;
  late String _deckName = widget.deckName;

  /// 菜单:新建子分组 / 重命名 / 移动到… / 删除分组。
  ///
  /// 与首页分组行的「⋮」同一套动作（需求 P0-9 / P1-12）：以前详情页只有
  /// 重命名和删除，进到子组里想再建一层就得退回首页。
  Future<void> _onMenu(String action) async {
    final repo = ref.read(repoProvider);
    if (action == 'child') return _addChild(repo);
    if (action == 'move') return _move(repo);

    if (action == 'rename') {
      final ctrl = TextEditingController(text: _deckName);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('重命名分组'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分组名称'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty || name == _deckName) return;
      try {
        await repo.renameDeck(widget.deckId, name);
      } on DeckNameConflictException catch (e) {
        if (mounted) _toast(context, e.toString());
        return;
      }
      if (mounted) setState(() => _deckName = name);
      // 面包屑画的是父链，祖先改名也要跟着刷，不然顶上的路径还是旧名字。
      ref.invalidate(decksProvider);
      ref.invalidate(_deckChainProvider(widget.deckId));
      return;
    }

    if (action == 'delete') {
      // 删除前先按真实子树把影响面查出来，确认框里必须是实测数字
      //（P0-10：只说"及其所有卡片"用户不知道会带走几个子分组）。
      final all = await repo.liveDecks();
      final childCount = descendantIds(all, widget.deckId).length;
      final cardCount = (await repo.deckCounts(widget.deckId)).totalCards;
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final p = InkPalette.of(ctx);
          final scope = childCount > 0
              ? '及其 $childCount 个子分组、$cardCount 张卡片'
              : '及其中 $cardCount 张卡片';
          return AlertDialog(
            title: Text('删除「$_deckName」？'),
            content: Text('将删除该分组$scope。删除后进入回收站，可恢复。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消')),
              InkButton(
                label: '删除',
                tone: InkTone.solid,
                color: p.cinnabar,
                deep: p.cinnabarDeep,
                expand: false,
                height: 44,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      );
      if (ok != true) return;
      await repo.deleteDeck(widget.deckId);
      ref.invalidate(decksProvider);
      if (!mounted) return;
      Navigator.of(context).pop(); // 返回列表
    }
  }

  /// 在当前分组下再建一层；已到 5 层上限则不发起（菜单项本身也置灰）。
  Future<void> _addChild(CollectionRepo repo) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('在「$_deckName」下新建子分组'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '子分组名称'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          InkButton(
            label: '创建',
            expand: false,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await repo.createDeck(name, parentId: widget.deckId);
    } on DeckDepthException catch (e) {
      if (mounted) _toast(context, e.toString());
      return;
    } on DeckNameConflictException catch (e) {
      if (mounted) _toast(context, e.toString());
      return;
    }
    if (!mounted) return;
    _toast(context, '已在「$_deckName」下创建「$name」');
    ref.invalidate(decksProvider);
    ref.invalidate(deckCountsProvider(widget.deckId));
  }

  /// 把当前分组移到别的父分组（或移到顶层）。
  /// 目标候选排除自己与自己的后代，否则 parentId 成环（P1-12）。
  Future<void> _move(CollectionRepo repo) async {
    const topSentinel = '__top__'; // showDialog 返回 null 表示"取消"，故另设哨兵
    final all = await repo.liveDecks();
    final excluded = subtreeIds(all, widget.deckId);
    final candidates = all.where((d) => !excluded.contains(d.id)).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      _toast(context, '没有其它分组可移动');
      return;
    }

    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('把「$_deckName」移动到'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, topSentinel),
            child: const Text('顶层（不作为子分组）'),
          ),
          for (final d in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d.id),
              // 不同父下允许同名，只显示名字会撞，所以带上完整路径。
              child: Text(joinDeckPath(
                  [for (final a in chainOf(all, d.id)) a.name], separator: ' › ')),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    try {
      await repo.moveDeck(widget.deckId, target == topSentinel ? null : target);
    } on DeckCycleException catch (e) {
      if (mounted) _toast(context, e.toString());
      return;
    } on DeckDepthException catch (e) {
      if (mounted) _toast(context, e.toString());
      return;
    } on DeckNameConflictException catch (e) {
      if (mounted) _toast(context, e.toString());
      return;
    }
    if (!mounted) return;
    _toast(context, '已移动「$_deckName」，返回上一级查看新位置');
    ref.invalidate(decksProvider);
    ref.invalidate(_deckChainProvider(widget.deckId));
    ref.invalidate(deckCountsProvider(widget.deckId));
  }

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final countsAsync = ref.watch(deckCountsProvider(widget.deckId));
    final cardsAsync = ref.watch(_deckCardsProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_deckName),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_deckCardsProvider(widget.deckId));
              ref.invalidate(deckCountsProvider(widget.deckId));
            },
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (v) => _onMenu(v),
            // 深度用面包屑的父链算（同一个 provider，已经在 build 里加载）。
            itemBuilder: (_) {
              final depth =
                  ref.read(_deckChainProvider(widget.deckId)).valueOrNull?.length ??
                      1;
              final canAdd = depth < kMaxDeckDepth;
              return [
                PopupMenuItem(
                  value: 'child',
                  enabled: canAdd,
                  child: Row(
                    children: [
                      const Text('新建子分组'),
                      const Spacer(),
                      if (!canAdd)
                        Text('已达 $kMaxDeckDepth 层',
                            style: TextStyle(fontSize: 11.5, color: p.ink3)),
                    ],
                  ),
                ),
                const PopupMenuItem(value: 'rename', child: Text('重命名分组')),
                const PopupMenuItem(value: 'move', child: Text('移动到…')),
                const PopupMenuItem(value: 'delete', child: Text('删除分组')),
              ];
            },
          ),
          const SizedBox(width: InkTokens.s1),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // 宽屏(Windows)限宽居中，避免卡片网格被横向拉大。
          constraints: const BoxConstraints(maxWidth: InkTokens.gridMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s8),
            children: [
              _breadcrumb(p),
              countsAsync.when(
                loading: () => const SizedBox(height: 96),
                error: (_, _) => const SizedBox(height: 96),
                data: (counts) => _header(context, counts, p),
              ),
              const SizedBox(height: InkTokens.s5),
              InkSection(
                title: '卡片',
                padding: const EdgeInsets.only(bottom: InkTokens.s2),
              ),
              _filterTabs(p),
              const SizedBox(height: InkTokens.s3),
              cardsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: InkTokens.s8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    InkEmpty(title: '卡片加载失败', hint: '$e', icon: Icons.error_outline),
                data: (items) {
                  final filtered = _applyFilter(items);
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: InkTokens.s6),
                      child: InkEmpty(
                        title: '这里还没有卡片',
                        hint: '点下方「添加卡片到本组」新建，或换个筛选条件',
                        icon: Icons.style_outlined,
                      ),
                    );
                  }
                  // 响应式列数：按可用宽度自适应，宽屏自动多列。
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth - InkTokens.s8;
                      final cols = (w / 300).clamp(2, 5).floor();
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: InkTokens.s3,
                          crossAxisSpacing: InkTokens.s3,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _cardTile(context, filtered[i], p),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      // 添加口统一放下方（与底部导航的「添加」同一心智），右上角不再放 +。
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            InkTokens.s4, 0, InkTokens.s4, InkTokens.s3),
        child: InkButton(
          label: '添加卡片到本组',
          icon: Icons.add,
          tone: InkTone.pale,
          height: 50,
          onPressed: () => showAddCardSheet(context, deckId: widget.deckId),
        ),
      ),
    );
  }

  /// 面包屑：`大模型 › 深度学习`。顶层分组不显示（没意义）。
  /// 深度 5 时中间用省略号占位，避免挤成一行乱码。
  Widget _breadcrumb(InkPalette p) {
    final chain = ref.watch(_deckChainProvider(widget.deckId));
    return chain.maybeWhen(
      data: (list) {
        if (list.length < 2) return const SizedBox.shrink();
        var shown = list;
        var elided = false;
        if (list.length > 3) {
          shown = [list.first, list[list.length - 2], list.last];
          elided = true;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: InkTokens.s2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkTokens.s1),
                    child: Text(elided && i == 1 ? '› … ›' : '›',
                        style: TextStyle(fontSize: 12.5, color: p.ink3)),
                  ),
                  _crumb(shown[i], i == shown.length - 1, p),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _crumb(Deck d, bool isCurrent, InkPalette p) {
    if (isCurrent) {
      return Text(d.name,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink1));
    }
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DeckDetailScreen(deckId: d.id, deckName: d.name),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(d.name,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.primary)),
      ),
    );
  }

  /// 封面头卡：墨青封面 + 统计 + 墨痕进度 + 开始学习。
  Widget _header(BuildContext context, dynamic counts, InkPalette p) {
    final due = counts.total as int;
    final studied = counts.studiedCards as int;
    final total = counts.totalCards as int;

    return InkCard(
      raise: false,
      borderColor: p.primary.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(InkTokens.s4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.primaryPale,
                  borderRadius: BorderRadius.circular(InkTokens.rButton),
                  border: Border.all(
                      color: p.primary.withValues(alpha: 0.3), width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.deckName.isEmpty ? '?' : widget.deckName.characters.first,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: p.primary),
                ),
              ),
              const SizedBox(width: InkTokens.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.deckName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '新卡 ${counts.newCards} · 待复习 $due · 已学 $studied/$total',
                      style: TextStyle(fontSize: 12.5, color: p.ink3),
                    ),
                  ],
                ),
              ),
              if (total == 0)
                InkChip(label: '空分组', color: p.ink3, dense: true)
              else if (due > 0)
                InkChip(label: '$due 待学', color: p.cinnabar, dense: true)
              else
                InkChip(label: '已清空', color: p.pine, dense: true),
            ],
          ),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.only(top: InkTokens.s2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('这个分组还没有卡片。',
                    style: TextStyle(fontSize: 12.5, color: p.ink3)),
              ),
            )
          else ...[
            const SizedBox(height: InkTokens.s3),
            InkStrokeBar(
                value: studied / total,
                height: 8,
                color: p.primary,
                deepColor: p.primaryDeep),
            const SizedBox(height: InkTokens.s2),
            Row(
              children: [
                Text('${(studied / total * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: p.ink2)),
                const Spacer(),
                Text('共 $total 张', style: TextStyle(fontSize: 12, color: p.ink3)),
              ],
            ),
          ],
          const SizedBox(height: InkTokens.s3),
          // 空分组这里不放按钮——底部的「添加卡片到本组」已经承担了同一动作，
          // 再放一个就是重复入口。
          if (total > 0)
            if (due > 0)
              InkButton(
                label: '开始学习',
                icon: Icons.play_arrow_rounded,
                height: 48,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                      deckId: widget.deckId, deckName: widget.deckName),
                )),
              )
            else
              InkButton(
                label: '本组今日已学完',
                icon: Icons.check_rounded,
                tone: InkTone.pale,
                height: 48,
                onPressed: null,
              ),
        ],
      ),
    );
  }

  /// 筛选标签：全部 / 未学 / 记忆中。
  Widget _filterTabs(InkPalette p) {
    return Row(
      children: [
        _tab(p, DeckFilter.all, '全部'),
        const SizedBox(width: InkTokens.s2),
        _tab(p, DeckFilter.newOnly, '未学'),
        const SizedBox(width: InkTokens.s2),
        _tab(p, DeckFilter.learning, '记忆中'),
      ],
    );
  }

  Widget _tab(InkPalette p, DeckFilter f, String label) {
    final selected = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: InkTokens.motionFast,
        padding: const EdgeInsets.symmetric(
            horizontal: InkTokens.s4, vertical: InkTokens.s2),
        decoration: BoxDecoration(
          color: selected ? p.primaryPale : p.card,
          borderRadius: BorderRadius.circular(InkTokens.rChip),
          border: Border.all(
            color: selected ? p.primary.withValues(alpha: 0.45) : p.line,
            width: InkTokens.borderWidth,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.primary : p.ink2,
          ),
        ),
      ),
    );
  }

  List<BrowseItem> _applyFilter(List<BrowseItem> items) {
    switch (_filter) {
      case DeckFilter.all:
        return items;
      case DeckFilter.newOnly:
        return items.where((i) => i.card.queue == Queue.newCard).toList();
      case DeckFilter.learning:
        return items
            .where((i) =>
                i.card.queue == Queue.learning ||
                i.card.queue == Queue.relearning ||
                i.card.queue == Queue.review)
            .toList();
    }
  }

  /// 卡片缩略图：正面 + 背面预览 + 状态脚注 + 常驻操作按钮。
  Widget _cardTile(BuildContext context, BrowseItem item, InkPalette p) {
    final isNew = item.card.queue == Queue.newCard;
    final suspended = item.card.queue == Queue.suspended;
    final status = suspended
        ? '已挂起'
        : (isNew ? '新卡' : '已学');
    final statusColor =
        suspended ? p.ink3 : (isNew ? p.primary : p.pine);

    return InkCard(
      padding: const EdgeInsets.all(InkTokens.s3),
      radius: InkTokens.rButton,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ReviewScreen(deckId: widget.deckId, deckName: widget.deckName),
        ));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.displayFront,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              item.displayBack,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: p.ink3),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              InkChip(label: status, color: statusColor, dense: true),
              const Spacer(),
              // 操作按钮常驻可见，不靠 hover 显形。
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: '卡片操作',
                icon: Icon(Icons.more_horiz, size: 19, color: p.ink2),
                onPressed: () => _cardMenu(item, context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 卡片操作菜单:编辑 / 移动到分组 / 删除。
  Future<void> _cardMenu(BrowseItem item, BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final p = InkPalette.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: InkTokens.s3),
                  decoration: BoxDecoration(
                      color: p.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑内容'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('移动到分组'),
                onTap: () => Navigator.pop(ctx, 'move'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: p.cinnabar),
                title: Text('删除', style: TextStyle(color: p.cinnabar)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              const SizedBox(height: InkTokens.s2),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'edit':
        await _editCard(item, context);
      case 'move':
        await _moveCard(item, context);
      case 'delete':
        await _deleteCard(item, context);
    }
  }

  /// 编辑卡片:改字段(基本=正/背,完形=文本)与标签。
  Future<void> _editCard(BrowseItem item, BuildContext context) async {
    final note = item.note;
    final fields = _decodeFields(note.fields);
    final isCloze = fields.length < 2;

    final frontCtrl = TextEditingController(text: fields.isNotEmpty ? fields[0] : '');
    final backCtrl =
        TextEditingController(text: fields.length > 1 ? fields[1] : '');
    final tagCtrl = TextEditingController(text: note.tags);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑卡片'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: frontCtrl,
                maxLines: isCloze ? 4 : 2,
                decoration: InputDecoration(
                  labelText: isCloze ? '文本(用 {{c1::答案}} 标注挖空)' : '正面(问题)',
                ),
              ),
              if (!isCloze) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: backCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '背面(答案)'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(
                  labelText: '标签(空格分隔)',
                  hintText: '例如:apple fruit',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;

    final newFields = isCloze
        ? [frontCtrl.text.trim()]
        : [frontCtrl.text.trim(), backCtrl.text.trim()];
    final newTags = tagCtrl.text
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final repo = ref.read(repoProvider);
    await repo.updateNoteContent(
      noteId: note.id,
      fields: newFields,
      tags: newTags,
    );
    _refresh();
  }

  /// 移动卡片到另一分组。
  Future<void> _moveCard(BrowseItem item, BuildContext context) async {
    final repo = ref.read(repoProvider);
    final decks = await repo.allDecks();
    if (!context.mounted) return;
    final candidates = decks.where((d) => d.id != widget.deckId).toList();
    if (candidates.isEmpty) {
      _toast(context, '没有其它分组可移动');
      return;
    }

    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到分组'),
        children: candidates
            .map((d) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d.id),
                  child: Text(d.name),
                ))
            .toList(),
      ),
    );
    if (target == null || !context.mounted) return;

    await repo.moveCard(cardId: item.card.id, toDeckId: target);
    _refresh();
    final name = candidates.firstWhere((d) => d.id == target).name;
    if (!context.mounted) return;
    _toast(context, '已移动到「$name」');
  }

  /// 删除卡片(确认后软删除)。
  Future<void> _deleteCard(BrowseItem item, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = InkPalette.of(ctx);
        return AlertDialog(
          title: const Text('删除这张卡片?'),
          content: Text('「${item.displayFront}」将被删除。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            InkButton(
              label: '删除',
              tone: InkTone.solid,
              color: p.cinnabar,
              deep: p.cinnabarDeep,
              expand: false,
              height: 44,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;

    final repo = ref.read(repoProvider);
    await repo.deleteCard(item.card.id);
    _refresh();
    if (!context.mounted) return;
    _toast(context, '已删除');
  }

  /// 刷新卡片网格与统计。
  void _refresh() {
    ref.invalidate(_deckCardsProvider(widget.deckId));
    ref.invalidate(deckCountsProvider(widget.deckId));
    ref.invalidate(decksProvider);
  }

  void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
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
