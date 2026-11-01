import 'dart:async';

import 'package:flutter/material.dart';

/// 全局路由观察器:用于监听"进入/退回首页"以切换标语。
///
/// 需在 MaterialApp.navigatorObservers 中注册本实例。
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

/// 首页励志标语轮播:淡入淡出自动切换(每 5 分钟),
/// 且每次进入或退回首页时切换下一句。
///
/// 放在待学概览与牌组列表之间,打开即见,不干扰学习流程。
class QuoteCarousel extends StatefulWidget {
  const QuoteCarousel({
    super.key,
    this.quotes = kQuotes,
    this.interval = const Duration(minutes: 5),
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

class _QuoteCarouselState extends State<QuoteCarousel> with RouteAware {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.quotes.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) => _advance());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅路由观察器,监听"进入/退回首页"。
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _timer?.cancel();
    super.dispose();
  }

  /// 切换到下一句。
  void _advance() {
    if (!mounted || widget.quotes.length < 2) return;
    setState(() => _index = (_index + 1) % widget.quotes.length);
  }

  // 首页路由被"进入"或"从上层返回"时,切换下一句。
  @override
  void didPush() {
    // 首次进入不切换(显示第一句),避免启动时跳一下。
  }

  @override
  void didPopNext() {
    // 从详情页退回首页 -> 切换。
    _advance();
  }

  @override
  void didPushNext() {
    // 离开首页(跳到详情) -> 不切换。
  }

  @override
  void didPop() {
    // 本路由被弹出,无需处理。
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
