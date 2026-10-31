import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/fsrs/fsrs.dart';

void main() {
  test('FSRS 新卡四档间隔满足单调性', () {
    final fsrs = Fsrs();
    final ns = fsrs.nextStates(null, 0.9, 0);
    expect(ns.easy.interval, greaterThan(ns.good.interval));
    expect(ns.good.interval, greaterThan(ns.hard.interval));
    expect(ns.hard.interval, greaterThan(ns.again.interval));
  });

  test('FSRS 关键参考值（good 新卡稳定性 = w2 = 3.9221）', () {
    final fsrs = Fsrs();
    final good = fsrs.nextStates(null, 0.9, 0).good;
    expect(good.memory.stability, closeTo(3.9221, 1e-3));
    expect(good.memory.stabilityFast, closeTo(3.13768, 1e-3));
  });
}
