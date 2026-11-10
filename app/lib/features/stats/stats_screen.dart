import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/stats_providers.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';

/// 统计页（底部导航第二个 tab）：今日驾驶舱式概览 + 近 7 天 + 状态分布。
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = InkPalette.of(context);
    final activity = ref.watch(reviewActivityProvider);
    final dist = ref.watch(cardDistributionProvider);
    final summary = ref.watch(reviewSummaryProvider);
    final streak = ref.watch(studyStreakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: InkPage(
        padding: const EdgeInsets.fromLTRB(
            InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s8),
        children: [
          _heroRow(p, summary, streak),
          const SizedBox(height: InkTokens.s5),
          InkSection(
              title: '近 7 天复习量',
              padding: const EdgeInsets.only(bottom: InkTokens.s2)),
          InkCard(
            raise: false,
            padding: const EdgeInsets.fromLTRB(
                InkTokens.s4, InkTokens.s5, InkTokens.s4, InkTokens.s4),
            child: activity.when(
              loading: () => const SizedBox(
                  height: 132, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('加载失败：$e', style: TextStyle(color: p.cinnabar)),
              data: (days) => _BarChart(days: days),
            ),
          ),
          const SizedBox(height: InkTokens.s5),
          InkSection(
              title: '卡片状态',
              padding: const EdgeInsets.only(bottom: InkTokens.s2)),
          InkCard(
            raise: false,
            padding: const EdgeInsets.all(InkTokens.s4),
            child: dist.when(
              loading: () => const SizedBox(
                  height: 90, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('加载失败：$e', style: TextStyle(color: p.cinnabar)),
              data: (d) => Column(
                children: [
                  _distRow(context, '新卡', d.newCards, d.total, p.primary),
                  _distRow(context, '学习中', d.learning, d.total, p.ochre),
                  _distRow(context, '复习', d.review, d.total, p.pine),
                  _distRow(context, '已挂起', d.suspended, d.total, p.ink3),
                  const SizedBox(height: InkTokens.s2),
                  Divider(height: 1, thickness: 1, color: p.line),
                  const SizedBox(height: InkTokens.s3),
                  Row(
                    children: [
                      Text('总计',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink1)),
                      const Spacer(),
                      Text('${d.total}',
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部：连续打卡（朱砂大数字）+ 累计复习 + 保持率。
  Widget _heroRow(InkPalette p, AsyncValue<ReviewSummary> summary, AsyncValue<int> streak) {
    final s = summary.valueOrNull;
    final days = streak.valueOrNull ?? 0;

    return InkCard(
      raise: false,
      borderColor: p.primary.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: InkTokens.s4, vertical: InkTokens.s5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$days',
                        style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            color: days > 0 ? p.cinnabar : p.ink3)),
                    const SizedBox(width: InkTokens.s2),
                    Text('天连续', style: TextStyle(fontSize: 14, color: p.ink2)),
                    const SizedBox(width: 6),
                    Icon(Icons.local_fire_department,
                        size: 20, color: days > 0 ? p.cinnabar : p.ink3),
                  ],
                ),
                const SizedBox(height: 2),
                Text(days > 0 ? '今天也来一点，别断' : '今天还没开始，学一张也算',
                    style: TextStyle(fontSize: 12.5, color: p.ink3)),
              ],
            ),
          ),
          Container(width: 1, height: 52, color: p.line),
          const SizedBox(width: InkTokens.s4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniStat(p, '累计复习', s == null ? '…' : '${s.total}', p.ink1),
              const SizedBox(height: InkTokens.s3),
              _miniStat(
                  p,
                  '保持率',
                  s == null
                      ? '…'
                      : (s.total == 0 ? '—' : '${(s.retention * 100).toStringAsFixed(0)}%'),
                  p.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(InkPalette p, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 11.5, color: p.ink3)),
      ],
    );
  }

  Widget _distRow(
      BuildContext context, String label, int value, int total, Color color) {
    final p = InkPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkTokens.s2),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: InkTokens.s2),
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(fontSize: 13.5)),
          ),
          Expanded(
            child: InkStrokeBar(
              value: total == 0 ? 0 : value / total,
              height: 7,
              color: color,
              deepColor: color,
              trackColor: p.sunken,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
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
    final p = InkPalette.of(context);
    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    final today = DateTime.now();

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      d.count > 0 ? '${d.count}' : '',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.ink2),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: InkTokens.motionBase,
                      curve: InkTokens.easeSpring,
                      height: maxCount == 0 ? 5 : (d.count / maxCount) * 82 + 5,
                      decoration: BoxDecoration(
                        color: d.count > 0 ? p.primary : p.sunken,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                        border: Border.all(
                          color: d.count > 0 ? p.primaryDeep : p.line,
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[d.day.weekday % 7],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: d.day.day == today.day ? FontWeight.w700 : FontWeight.w400,
                        color: d.day.day == today.day ? p.ink1 : p.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
