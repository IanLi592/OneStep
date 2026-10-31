import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' as data;
import '../../core/domain/browser_service.dart';
import '../../core/domain/collection_repo.dart' show Queue;
import '../../core/domain/providers.dart';

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

/// 搜索结果（FutureProvider.family 依赖过滤条件）。
final _resultsProvider = FutureProvider<List<BrowseItem>>((ref) async {
  final f = ref.watch(_filtersProvider);
  final db = ref.watch(dbProvider);
  return BrowserService(db).search(f.toQuery());
});

/// 卡片浏览器：搜索 + 过滤 + 挂起/删除。
class BrowserScreen extends ConsumerWidget {
  const BrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_resultsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('浏览卡片')),
      body: Column(
        children: [
          _FilterBar(),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('搜索失败：$e')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('没有匹配的卡片'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => _tile(context, ref, items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, BrowseItem item) {
    final scheme = Theme.of(context).colorScheme;
    final suspended = item.card.queue == Queue.suspended;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(
          item.displayFront,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: suspended ? scheme.outline : null),
        ),
        subtitle: Text(
          suspended ? '已挂起' : _stateLabel(item.card.queue),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _act(context, ref, item, v),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'suspend', child: Text(suspended ? '取消挂起' : '挂起')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
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

  Future<void> _act(BuildContext context, WidgetRef ref, BrowseItem item, String v) async {
    final db = ref.read(dbProvider);
    final svc = BrowserService(db);
    if (v == 'suspend') {
      await svc.setSuspended(item.card.id, item.card.queue != Queue.suspended);
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('删除这张卡片？'),
          content: const Text('删除后可通过同步传播；此操作可撤销性有限。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
          ],
        ),
      );
      if (ok != true) return;
      await svc.deleteCard(item.card.id);
    }
    ref.invalidate(_resultsProvider);
  }
}

/// 过滤条：牌组 / 标签 / 状态 / 文本。
class _FilterBar extends ConsumerStatefulWidget {
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
    if (mounted) setState(() { _tags = tags; _decks = decks; });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(_filtersProvider);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _textCtrl,
            decoration: InputDecoration(
              hintText: '搜索正面/背面/标签…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _textCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _textCtrl.clear(); _update(text: ''); },
                    )
                  : null,
            ),
            onChanged: (v) => _update(text: v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _deckDropdown(f)),
              const SizedBox(width: 8),
              Expanded(child: _tagDropdown(f)),
              const SizedBox(width: 8),
              Expanded(child: _stateDropdown(f)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deckDropdown(_Filters f) {
    return DropdownButtonFormField<String?>(
      initialValue: f.deckId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '牌组', isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('全部')),
        ..._decks.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => _update(deckId: v),
    );
  }

  Widget _tagDropdown(_Filters f) {
    return DropdownButtonFormField<String?>(
      initialValue: f.tag,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '标签', isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('全部')),
        ..._tags.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => _update(tag: v),
    );
  }

  Widget _stateDropdown(_Filters f) {
    return DropdownButtonFormField<CardState?>(
      initialValue: f.state,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '状态', isDense: true),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: CardState.newCard, child: Text('新卡')),
        DropdownMenuItem(value: CardState.learning, child: Text('学习中')),
        DropdownMenuItem(value: CardState.review, child: Text('复习')),
        DropdownMenuItem(value: CardState.suspended, child: Text('已挂起')),
      ],
      onChanged: (v) => _update(state: v),
    );
  }

  void _update({String? deckId, String? tag, CardState? state, String? text}) {
    final cur = ref.read(_filtersProvider);
    ref.read(_filtersProvider.notifier).state = _Filters(
      deckId: deckId ?? cur.deckId,
      tag: tag ?? cur.tag,
      state: state ?? cur.state,
      text: text ?? cur.text,
    );
  }
}
