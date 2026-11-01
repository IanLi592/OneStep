import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/providers.dart';
import '../browser/browser_screen.dart';
import '../card_edit/add_card_sheet.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

/// 首页：牌组列表，每个牌组显示今日"新/学习/到期"数量，一步进入学习。
class DeckListScreen extends ConsumerStatefulWidget {
  const DeckListScreen({super.key});

  @override
  ConsumerState<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends ConsumerState<DeckListScreen> {
  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(decksProvider);
    final scheme = Theme.of(context).colorScheme;

    // 牌组/计数变化时，把最新待复习总数推给桌面小组件。
    ref.listen(decksProvider, (_, _) => _pushWidget());

    return Scaffold(
      appBar: AppBar(
        title: const Text('跬步'),
        actions: [
          IconButton(
            tooltip: '浏览卡片',
            icon: const Icon(Icons.style_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BrowserScreen()),
            ),
          ),
          IconButton(
            tooltip: '统计',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: '新增分组',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showCreateDeckDialog(context),
          ),
          IconButton(
            tooltip: '添加卡片',
            icon: const Icon(Icons.add),
            onPressed: () => _openAddCard(context),
          ),
        ],
      ),
      body: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (decks) {
          if (decks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style_outlined, size: 64, color: scheme.outline),
                  const SizedBox(height: 12),
                  const Text('还没有牌组', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _openAddCard(context),
                    child: const Text('添加第一张卡片'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: decks.length,
            itemBuilder: (context, i) {
              final deck = decks[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeckCard(deckId: deck.id, deckName: deck.name),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAddCard(BuildContext context) async {
    await showAddCardSheet(context);
  }

  /// 把最新待复习总数推送到桌面小组件。
  void _pushWidget() {
    // 异步推送，失败不影响主流程。
    ref.read(widgetUpdaterProvider).push();
  }

  /// 新增分组：弹窗输入名称，创建后刷新列表。
  Future<void> _showCreateDeckDialog(BuildContext context) async {
    final controller = TextEditingController();
    final repo = ref.read(repoProvider);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '分组名称',
            hintText: '例如：英语单词',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await repo.createDeck(name);
      // 刷新牌组列表与桌面小组件。
      ref.invalidate(decksProvider);
      _pushWidget();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建分组「$name」'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败：$e')),
        );
      }
    }
  }
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard({required this.deckId, required this.deckName});

  final String deckId;
  final String deckName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(deckCountsProvider(deckId));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReviewScreen(deckId: deckId, deckName: deckName),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: countsAsync.when(
            loading: () => Text(deckName),
            error: (_, _) => Text(deckName),
            data: (counts) {
              final hasDue = counts.total > 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(deckName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.chevron_right, color: scheme.outline),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (hasDue)
                    Row(
                      children: [
                        _countChip('新 $counts.newCards', scheme.primary),
                        const SizedBox(width: 8),
                        _countChip('学习 ${counts.learning}', scheme.tertiary),
                        const SizedBox(width: 8),
                        _countChip('到期 ${counts.review}', scheme.secondary),
                      ],
                    )
                  else
                    Text('今日已清空 ✓',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _countChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
