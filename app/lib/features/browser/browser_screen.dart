import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' as data;
import '../../core/domain/browser_service.dart';
import '../../core/domain/collection_repo.dart' show Queue;
import '../../core/domain/providers.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';

/// 浏览器搜索条件的本地状态。
class _Filters {
  const _Filters({this.deckId, this.tag, this.state, this.text});
  final String? deckId;
  final String? tag;
  final CardState? state;
  final String? text;

  CardQuery toQuery() => CardQuery(deckId: deckId, tag: tag, state: state, text: text);
}

final _filtersProvider = StateProvider<_Filters>((ref) => const _Filters());

/// 搜索结果（FutureProvider 依赖过滤条件）。
final _resultsProvider = FutureProvider<List<BrowseItem>>((ref) async {
  final f = ref.watch(_filtersProvider);
  final db = ref.watch(dbProvider);
  return BrowserService(db).search(f.toQuery());
});

/// 卡片浏览器：搜索 + 过滤 + 挂起 / 删除。
class BrowserScreen extends ConsumerWidget {
  const BrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = InkPalette.of(context);
    final results = ref.watch(_resultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('浏览卡片')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: InkTokens.pageMaxWidth),
          child: Column(
            children: [
              const _FilterBar(),
              Expanded(
                child: results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => InkEmpty(
                      title: '搜索失败', hint: '$e', icon: Icons.error_outline),
                  data: (items) {
                    if (items.isEmpty) {
                      return InkEmpty(
                        title: '没有匹配的卡片',
                        hint: '换个关键词，或把上方的筛选条件改回"全部"',
                        icon: Icons.search_off,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(InkTokens.s4, 0,
                          InkTokens.s4, InkTokens.s6),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: InkTokens.s2),
                      itemBuilder: (context, i) => _tile(context, ref, p, items[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, WidgetRef ref, InkPalette p, BrowseItem item) {
    final suspended = item.card.queue == Queue.suspended;
    final state = _stateLabel(item.card.queue);
    final stateColor = suspended
        ? p.ink3
        : (item.card.queue == Queue.newCard
            ? p.primary
            : (item.card.queue == Queue.review ? p.pine : p.ochre));

    return InkCard(
      padding: const EdgeInsets.fromLTRB(
          InkTokens.s4, InkTokens.s3, InkTokens.s2, InkTokens.s3),
      onTap: () => _showActions(context, ref, item, suspended),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayFront,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: suspended ? p.ink3 : p.ink1,
                    decoration: suspended ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.displayBack,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: p.ink3),
                ),
                const SizedBox(height: InkTokens.s2),
                InkChip(label: state, color: stateColor, dense: true),
              ],
            ),
          ),
          IconButton(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showActions(context, ref, item, suspended),
          ),
        ],
      ),
    );
  }

  String _stateLabel(int q) => switch (q) {
        Queue.newCard => '新卡',
        Queue.learning || Queue.relearning => '学习中',
        Queue.review => '复习',
        Queue.suspended => '已挂起',
        _ => '未知',
      };

  Future<void> _showActions(
      BuildContext context, WidgetRef ref, BrowseItem item, bool suspended) async {
    final p = InkPalette.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: InkTokens.s2),
            ListTile(
              leading: Icon(suspended ? Icons.play_circle_outline : Icons.pause_circle_outline,
                  color: p.ink2),
              title: Text(suspended ? '取消挂起' : '挂起这张卡'),
              onTap: () => Navigator.pop(ctx, 'suspend'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: p.cinnabar),
              title: Text('删除', style: TextStyle(color: p.cinnabar)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: InkTokens.s2),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    await _act(context, ref, item, action);
  }

  Future<void> _act(
      BuildContext context, WidgetRef ref, BrowseItem item, String v) async {
    final db = ref.read(dbProvider);
    final svc = BrowserService(db);
    if (v == 'suspend') {
      await svc.setSuspended(item.card.id, item.card.queue != Queue.suspended);
    } else if (v == 'delete') {
      final p = InkPalette.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('删除这张卡片？'),
          content: Text('「${item.displayFront}」将被移入回收并停止复习。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            InkButton(
              label: '删除',
              tone: InkTone.danger,
              expand: false,
              height: 44,
              onPressed: () => Navigator.pop(context, true),
              color: p.cinnabar,
              deep: p.cinnabarDeep,
            ),
          ],
        ),
      );
      if (ok != true) return;
      await svc.deleteCard(item.card.id);
    }
    ref.invalidate(_resultsProvider);
    ref.invalidate(deckCountsProvider);
    ref.invalidate(decksProvider);
  }
}

/// 过滤条：搜索框 + 状态页签 + 分组 / 标签下拉。
class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar();

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _textCtrl = TextEditingController();
  List<String> _tags = [];
  List<data.Deck> _decks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final tags = await BrowserService(db).allTags();
    final decks = await ref.read(repoProvider).allDecks();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _decks = decks;
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final f = ref.watch(_filtersProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s3),
      child: Column(
        children: [
          TextField(
            controller: _textCtrl,
            decoration: InputDecoration(
              hintText: '搜索正面 / 背面 / 标签…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _textCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _textCtrl.clear();
                        _update(text: '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => _update(text: v),
          ),
          const SizedBox(height: InkTokens.s3),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _stateChip(f, null, '全部'),
                _stateChip(f, CardState.newCard, '新卡'),
                _stateChip(f, CardState.learning, '学习中'),
                _stateChip(f, CardState.review, '复习'),
                _stateChip(f, CardState.suspended, '已挂起'),
                const SizedBox(width: InkTokens.s2),
                _dropdown(p, f, Icons.folder_outlined, '分组',
                    [
                      const DropdownMenuItem<String?>(value: null, child: Text('全部分组')),
                      ..._decks.map((d) => DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(d.name, overflow: TextOverflow.ellipsis))),
                    ], f.deckId, (v) => _update(deckId: v)),
                const SizedBox(width: InkTokens.s2),
                _dropdown(p, f, Icons.sell_outlined, '标签', [
                  const DropdownMenuItem<String?>(value: null, child: Text('全部标签')),
                  ..._tags.map((t) => DropdownMenuItem<String?>(
                      value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
                ], f.tag, (v) => _update(tag: v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateChip(_Filters f, CardState? state, String label) {
    final selected = f.state == state;
    final p = InkPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: InkTokens.s2),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _update(state: state),
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? p.primary : p.ink2,
        ),
      ),
    );
  }

  Widget _dropdown(
    InkPalette p,
    _Filters f,
    IconData icon,
    String hint,
    List<DropdownMenuItem<String?>> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkTokens.s3),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(InkTokens.rChip),
        border: Border.all(color: p.line, width: InkTokens.borderWidth),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 18, color: p.ink3),
          style: TextStyle(fontSize: 13, color: p.ink2),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// 更新筛选条件。
  ///
  /// 用哨兵而不是 `??`：原写法 `_update(state: null)` 会被 `null ?? cur.state`
  /// 吃掉，导致点"全部"其实清不掉筛选条件。
  void _update({
    Object? deckId = _unset,
    Object? tag = _unset,
    Object? state = _unset,
    Object? text = _unset,
  }) {
    final cur = ref.read(_filtersProvider);
    ref.read(_filtersProvider.notifier).state = _Filters(
      deckId: identical(deckId, _unset) ? cur.deckId : deckId as String?,
      tag: identical(tag, _unset) ? cur.tag : tag as String?,
      state: identical(state, _unset) ? cur.state : state as CardState?,
      text: identical(text, _unset) ? cur.text : text as String?,
    );
  }
}

/// "参数未传"的哨兵对象（null 是合法值，不能兼任）。
const Object _unset = Object();
