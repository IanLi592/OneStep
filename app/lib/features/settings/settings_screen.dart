import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/providers.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';

/// 设置页：每日新卡上限、复习上限、期望记忆保持率。
///
/// 数值改动即时落库（onChangeEnd），不需要"保存"按钮。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _newPerDay;
  late int _maxReviews;
  late double _retention;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final repo = ref.read(repoProvider);
      _newPerDay = repo.newCardsPerDay;
      _maxReviews = repo.maxReviewsPerDay;
      _retention = repo.desiredRetention;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('学习设置')),
      body: InkPage(
        children: [
          InkSection(title: '每日节奏', padding: const EdgeInsets.only(bottom: InkTokens.s2)),
          InkCard(
            raise: false,
            padding: const EdgeInsets.fromLTRB(
                InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s2),
            child: Column(
              children: [
                _slider(
                  p,
                  label: '新卡上限',
                  hint: '每天最多引入多少张新卡',
                  value: _newPerDay.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  display: '$_newPerDay 张',
                  onChanged: (v) => setState(() => _newPerDay = v.round()),
                  onEnd: () async {
                    final repo = ref.read(repoProvider);
                    repo.newCardsPerDay = _newPerDay;
                    await repo.saveSettings();
                  },
                ),
                Divider(height: 1, thickness: 1, color: p.line),
                _slider(
                  p,
                  label: '复习上限',
                  hint: '每天最多复习多少张（含学习中）',
                  value: _maxReviews.toDouble(),
                  min: 20,
                  max: 500,
                  divisions: 24,
                  display: '$_maxReviews 张',
                  onChanged: (v) => setState(() => _maxReviews = v.round()),
                  onEnd: () async {
                    final repo = ref.read(repoProvider);
                    repo.maxReviewsPerDay = _maxReviews;
                    await repo.saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: InkTokens.s5),
          InkSection(title: '记忆', padding: const EdgeInsets.only(bottom: InkTokens.s2)),
          InkCard(
            raise: false,
            padding: const EdgeInsets.fromLTRB(
                InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s2),
            child: _slider(
              p,
              label: '期望记忆保持率',
              hint: '越高复习越频繁、记忆越牢；0.9 是兼顾效率的常用值',
              value: _retention,
              min: 0.70,
              max: 0.97,
              divisions: 27,
              display: '${(_retention * 100).toStringAsFixed(0)}%',
              onChanged: (v) => setState(() => _retention = v),
              onEnd: () async {
                final repo = ref.read(repoProvider);
                repo.desiredRetention = _retention;
                await repo.saveSettings();
              },
            ),
          ),
          const SizedBox(height: InkTokens.s5),
          InkCard(
            raise: false,
            padding: const EdgeInsets.all(InkTokens.s4),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: p.ink3),
                const SizedBox(width: InkTokens.s3),
                Expanded(
                  child: Text(
                    '这些设置只影响本机。复习间隔由 FSRS-7 依据你的打分实时计算。',
                    style: TextStyle(fontSize: 12.5, height: 1.6, color: p.ink2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    InkPalette p, {
    required String label,
    required String hint,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
    required Future<void> Function() onEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkTokens.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
              Text(display,
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700, color: p.primary)),
            ],
          ),
          Text(hint, style: TextStyle(fontSize: 12.5, color: p.ink3)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
            onChangeEnd: (_) => onEnd(),
          ),
        ],
      ),
    );
  }
}
