import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/shared/quote_carousel.dart';

/// 轮播组件测试:内容、自动切换、空列表容错。
void main() {
  test('内置 18 句标语', () {
    expect(kQuotes.length, 18);
    // 关键句在列。
    expect(kQuotes, contains('不积跬步，无以至千里'));
    expect(kQuotes, contains('日拱一卒，功不唐捐'));
    expect(kQuotes, contains('千里之行，始于足下'));
    // 统一全角标点(不含半角逗号)。
    expect(kQuotes.any((q) => q.contains(',')), isFalse);
  });

  testWidgets('轮播显示首句并按间隔自动切换', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuoteCarousel(interval: Duration(seconds: 1))),
      ),
    );
    // 初始显示第一句。
    expect(find.text('合抱之木，生于毫末'), findsOneWidget);

    // 推进超过一个间隔,应切换到第二句。
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(); // 触发动画状态
    expect(find.text('九层之台，起于累土'), findsOneWidget);
  });

  testWidgets('空列表不渲染也不崩', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuoteCarousel(quotes: [])),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(QuoteCarousel), findsOneWidget);
  });

  testWidgets('单句时不启动定时器、正常显示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteCarousel(quotes: ['只有这一句'], interval: Duration(seconds: 1)),
        ),
      ),
    );
    expect(find.text('只有这一句'), findsOneWidget);
    // 单句不应切换。
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('只有这一句'), findsOneWidget);
  });
}
