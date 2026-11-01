import 'dart:async';

import 'package:flutter/material.dart';

/// 首页励志标语轮播:淡入淡出自动切换。
///
/// 放在待学概览与牌组列表之间,打开即见,不干扰学习流程。
class QuoteCarousel extends StatefulWidget {
  const QuoteCarousel({
    super.key,
    this.quotes = kQuotes,
    this.interval = const Duration(seconds: 4),
  });

  /// 标语列表。
  final List<String> quotes;

  /// 自动切换间隔。
  final Duration interval;

  @override
  State<QuoteCarousel> createState() => _QuoteCarouselState();
}

/// 轮播标语(统一全角标点)。
const List<String> kQuotes = [
  '合抱之木，生于毫末',
  '九层之台，起于累土',
  '千里之行，始于足下',
  '不积小流，无以成江海',
  '不积跬步，无以至千里',
  '日拱一卒，功不唐捐',
  '积土成山，风雨兴焉',
  '积水成渊，蛟龙生焉',
  '锲而不舍，金石可镂',
  '博观而约取，厚积而薄发',
  '日日行，不怕千万里',
  '常常做，不怕千万事',
  '万事从来贵有恒',
  '有志者事竟成',
  '道阻且长，行则将至',
  '行而不辍，未来可期',
  '星光不问赶路人，时光不负有心人',
  '循梦而行，向阳而生',
];

class _QuoteCarouselState extends State<QuoteCarousel> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.quotes.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (!mounted || widget.quotes.isEmpty) return;
        setState(() => _index = (_index + 1) % widget.quotes.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final quote = widget.quotes[_index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.format_quote, size: 16, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: Text(
                  quote,
                  key: ValueKey<int>(_index), // 用下标作 key 触发切换动画
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
