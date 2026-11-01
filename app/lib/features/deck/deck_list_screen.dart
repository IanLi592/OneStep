import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' show Deck;
import '../../core/domain/providers.dart';
import '../../core/domain/xlsx_import_service.dart';
import '../browser/browser_screen.dart';
import '../card_edit/add_card_sheet.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import 'deck_detail_screen.dart';

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
            tooltip: '导入 Excel',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => _importXlsx(context),
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
      body: Column(
        children: [
          // 顶部概览:待学大数字 + 已学 + 去学习按钮。
          _buildSummary(context, ref),
          Expanded(
            child: decksAsync.when(
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
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /// 底部导航:首页 / 添加 / 我的。
  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      onTap: (i) {
        if (i == 1) {
          _openAddCard(context);
        } else if (i == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首页'),
        BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: '添加'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '我的'),
      ],
    );
  }

  /// 顶部概览:待学大数字 + 已学计数 + 去学习按钮(取第一个有待学习的牌组)。
  Widget _buildSummary(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final decksAsync = ref.watch(decksProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: decksAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (decks) {
          if (decks.isEmpty) return const SizedBox.shrink();
          // 汇总所有牌组的待学/已学。
          return FutureBuilder(
            future: _aggregateCounts(ref, decks),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final agg = snap.data!;
              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${agg.due}',
                              style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface)),
                          const SizedBox(width: 8),
                          Text('待学 / 已学 ${agg.studied}张',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 去学习按钮:进入第一个有待学习的牌组。
                  FilledButton(
                    onPressed: agg.dueDeckId == null
                        ? null
                        : () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                deckId: agg.dueDeckId!,
                                deckName: agg.dueDeckName ?? '',
                              ),
                            ));
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF6A623),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                    ),
                    child: const Text('去学习'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 汇总所有牌组的待学/已学总数,并找出第一个有待学习的牌组。
  Future<_Agg> _aggregateCounts(WidgetRef ref, List<Deck> decks) async {
    final repo = ref.read(repoProvider);
    var due = 0, studied = 0;
    String? dueDeckId;
    String? dueDeckName;
    for (final d in decks) {
      final c = await repo.deckCounts(d.id);
      due += c.total;
      studied += c.studiedCards;
      if (dueDeckId == null && c.total > 0) {
        dueDeckId = d.id;
        dueDeckName = d.name;
      }
    }
    return _Agg(due: due, studied: studied, dueDeckId: dueDeckId, dueDeckName: dueDeckName);
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

  /// 导入 Excel(.xlsx):选文件 -> 解析 -> 按牌组建卡 -> 反馈。
  Future<void> _importXlsx(BuildContext context) async {
    // 1) 选文件(仅 xlsx)。file_picker 13.x:返回 List<PlatformFile>。
    List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件选择器失败:$e')),
        );
      }
      return;
    }
    if (picked.isEmpty) return; // 用户取消
    final file = picked.first;

    try {
      // 2) 读字节。13.x:用 readAsBytes()(不再有 withData 参数)。
      final bytes = await file.readAsBytes();

      // 3) 导入。
      final repo = ref.read(repoProvider);
      final result = await XlsxImportService(repo).importBytes(bytes);

      if (result.cardsCreated == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未从文件中解析到可导入的卡片')),
          );
        }
        return;
      }

      // 4) 刷新列表与桌面小组件。
      ref.invalidate(decksProvider);
      _pushWidget();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入完成:${result.cardsCreated} 张卡片,'
              '${result.decksCreated} 个新分组'
              '${result.decksReused > 0 ? ',${result.decksReused} 个已有分组' : ''}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败:$e')),
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
    final cover = _deckCover(deckName);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DeckDetailScreen(deckId: deckId, deckName: deckName),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: countsAsync.when(
            loading: () => Text(deckName),
            error: (_, _) => Text(deckName),
            data: (counts) {
              final due = counts.total;
              final pct = (counts.progress * 100).round();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面占位:按牌组名生成的渐变方块。
                  Container(
                    width: 84,
                    height: 84,
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
                      deckName.isEmpty ? '?' : deckName.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 右侧信息区。
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(deckName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w600)),
                            ),
                            Icon(Icons.chevron_right, color: scheme.outline, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 待学习徽标 + 已学X/Y
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: due > 0
                                    ? const Color(0xFFF6A623).withValues(alpha: 0.18)
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                due > 0 ? '待学习 $due 张' : '今日已清空 ✓',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: due > 0
                                      ? const Color(0xFFC77C00)
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '已学 ${counts.studiedCards}/${counts.totalCards}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: counts.progress,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                                due > 0 ? const Color(0xFFF6A623) : scheme.primary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('进度 $pct%',
                            style: TextStyle(
                                fontSize: 11.5, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 按牌组名生成稳定的双色渐变(封面占位)。
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

/// 顶部概览的聚合数据。
class _Agg {
  const _Agg({
    required this.due,
    required this.studied,
    required this.dueDeckId,
    required this.dueDeckName,
  });

  final int due;
  final int studied;
  final String? dueDeckId;
  final String? dueDeckName;
}
