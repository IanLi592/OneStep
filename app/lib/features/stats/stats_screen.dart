import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/stats_providers.dart';

/// 统计页：近 7 天复习量、卡片状态、保持率、连续打卡。
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(reviewActivityProvider);
    final dist = ref.watch(cardDistributionProvider);
    final summary = ref.watch(reviewSummaryProvider);
    final streak = ref.watch(studyStreakProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 顶部三个概览
          Row(
            children: [
              _statCard(context, '累计复习', summary.maybeWhen(
                data: (s) => '${s.total}', orElse: () => '…'), scheme.primary),
              const SizedBox(width: 12),
              _statCard(context, '保持率', summary.maybeWhen(
                data: (s) => s.total == 0 ? '—' : '${(s.retention * 100).toStringAsFixed(0)}%',
                orElse: () => '…'), scheme.secondary),
              const SizedBox(width: 12),
              _statCard(context, '连续打卡', streak.maybeWhen(
                data: (d) => '$d 天', orElse: () => '…'), scheme.tertiary),
            ],
          ),
          const SizedBox(height: 20),

          // 近 7 天柱状图
          Text('近 7 天复习量', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: activity.when(
                loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败：$e'),
                data: (days) => _BarChart(days: days),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 卡片状态分布
          Text('卡片状态', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: dist.when(
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败：$e'),
                data: (d) => Column(
                  children: [
                    _distRow('新卡', d.newCards, scheme.primary),
                    _distRow('学习中', d.learning, scheme.tertiary),
                    _distRow('复习', d.review, scheme.secondary),
                    _distRow('已挂起', d.suspended, scheme.outline),
                    const Divider(height: 24),
                    _distRow('总计', d.total, scheme.onSurface, bold: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _distRow(String label, int value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text('$value', style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

/// 简易柱状图（无第三方依赖）。
class _BarChart extends StatelessWidget {
  const _BarChart({required this.days});

  final List<DailyCount> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final labels = ['日', '一', '二', '三', '四', '五', '六'];

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (d.count > 0)
                      Text('${d.count}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: maxCount == 0 ? 4 : (d.count / maxCount) * 90 + 4,
                      decoration: BoxDecoration(
                        color: d.count > 0 ? scheme.primary : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[d.day.weekday % 7],
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
