import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/browser_service.dart';
import '../../core/domain/collection_repo.dart' show Queue;
import '../../core/domain/providers.dart';
import '../review/review_screen.dart';

/// 牌组内卡片(供网格展示)。按筛选条件加载。
final _deckCardsProvider =
    FutureProvider.autoDispose.family<List<BrowseItem>, String>((ref, deckId) async {
  final db = ref.watch(dbProvider);
  return BrowserService(db).search(CardQuery(deckId: deckId));
});

/// 卡片筛选页签。
enum DeckFilter { all, newOnly, learning }

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countsAsync = ref.watch(deckCountsProvider(widget.deckId));
    final cardsAsync = ref.watch(_deckCardsProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckName),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_deckCardsProvider(widget.deckId));
              ref.invalidate(deckCountsProvider(widget.deckId));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 封面头卡。
          countsAsync.when(
            loading: () => const SizedBox(height: 160),
            error: (_, _) => const SizedBox(height: 160),
            data: (counts) => _header(context, counts, scheme),
          ),
          const SizedBox(height: 16),
          // 筛选标签。
          _filterTabs(scheme),
          const SizedBox(height: 12),
          // 卡片网格。
          cardsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Center(child: Text('加载失败:$e')),
            data: (items) {
              final filtered = _applyFilter(items);
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('没有卡片', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _cardTile(context, filtered[i], scheme),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 封面头卡:渐变封面 + 统计 + 开始记忆按钮。
  Widget _header(BuildContext context, dynamic counts, ColorScheme scheme) {
    final cover = _deckCover(widget.deckName);
    final due = counts.total as int;
    final studied = counts.studiedCards as int;
    final total = counts.totalCards as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cover.$1, cover.$2],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.deckName.isEmpty ? '?' : widget.deckName.characters.first,
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.deckName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('新卡 ${counts.newCards} | 待复习 $due',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : studied / total,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(scheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('已学 $studied/$total',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 筛选标签:全部 / 未学 / 记忆中。
  Widget _filterTabs(ColorScheme scheme) {
    return Row(
      children: [
        _tab(scheme, DeckFilter.all, '全部'),
        const SizedBox(width: 8),
        _tab(scheme, DeckFilter.newOnly, '未学'),
        const SizedBox(width: 8),
        _tab(scheme, DeckFilter.learning, '记忆中'),
      ],
    );
  }

  Widget _tab(ColorScheme scheme, DeckFilter f, String label) {
    final selected = _filter == f;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = f),
      selectedColor: scheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

  /// 卡片缩略图:正面 + 背面预览 + 状态脚注。
  Widget _cardTile(BuildContext context, BrowseItem item, ColorScheme scheme) {
    final isNew = item.card.queue == Queue.newCard;
    final status = isNew ? '新卡' : (item.card.queue == Queue.suspended ? '已挂起' : '已学');
    final statusColor = isNew ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReviewScreen(deckId: widget.deckId, deckName: widget.deckName),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 正面(标题)
            Text(
              item.displayFront,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 6),
            // 背面(预览)
            Expanded(
              child: Text(
                item.displayBack,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, size: 7, color: statusColor),
                const SizedBox(width: 4),
                Text(status, style: TextStyle(fontSize: 11.5, color: statusColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 按牌组名生成稳定渐变(与首页一致)。
  (Color, Color) _deckCover(String name) {
    const palette = [
      (Color(0xFF3B6EA5), Color(0xFF6FA8DC)),
      (Color(0xFF2E7D6B), Color(0xFF6FCF97)),
      (Color(0xFF8E5AA8), Color(0xFFC39BD3)),
      (Color(0xFFC75C5C), Color(0xFFF1948A)),
      (Color(0xFFD4883B), Color(0xFFF8C471)),
      (Color(0xFF4A6FA5), Color(0xFF85C1E9)),
    ];
    final h = name.isEmpty ? 0 : name.codeUnits.fold<int>(0, (a, c) => a + c);
    return palette[h % palette.length];
  }
}

/// 卡片筛选页签所需的队列常量(复用 collection_repo 的 Queue)。
// ignore: prefer_function_declarations_over_variables
