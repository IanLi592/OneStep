import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/fsrs/fsrs.dart';

/// FSRS-7 移植正确性测试。
///
/// 期望值取自官方 fsrs-rs 源码中的参考断言（新卡、desired_retention=0.9、
/// elapsed_days=0）：
///   again: S=0.1104  D=6.1686   Sfast=0.08832  I=3.8275626e-5
///   hard : S=2.2395  D=5.261278 Sfast=1.7916001 I=0.5974598
///   good : S=3.9221  D=3.5307243 Sfast=3.13768 I=4.7777247
///   easy : S=11.7841 D=1.0      Sfast=9.427279 I=53.869392
///
/// 官方参考用 f32，本实现用 f64，故给出合理容差。
void main() {
  const eps = 1e-3; // 状态量容差
  const epsInterval = 0.05; // 间隔容差（Newton + f32/f64 差异）

  group('FSRS-7 默认参数与初始量', () {
    test('默认参数为 34 个且有限', () {
      final fsrs = Fsrs();
      expect(fsrs.w.length, kFsrs7ParamLen);
      expect(fsrs.w.every((v) => v.isFinite), isTrue);
    });

    test('初始稳定度取 w[rating-1]', () {
      final fsrs = Fsrs();
      expect(fsrs.initStability(1), closeTo(0.1104, eps));
      expect(fsrs.initStability(2), closeTo(2.2395, eps));
      expect(fsrs.initStability(3), closeTo(3.9221, eps));
      expect(fsrs.initStability(4), closeTo(11.7841, eps));
    });

    test('初始难度公式 D0 = w4 - exp(w5*(r-1)) + 1', () {
      final fsrs = Fsrs();
      expect(fsrs.initDifficulty(1), closeTo(6.1686, eps));
      expect(fsrs.initDifficulty(2), closeTo(5.261278, eps));
      expect(fsrs.initDifficulty(3), closeTo(3.5307243, eps));
      // easy 触发 D_MIN=1.0 下限
      expect(fsrs.initDifficulty(4), closeTo(1.0, eps));
    });
  });

  group('nextStates（新卡）与官方参考值比对', () {
    test('新卡 @ retention=0.9, elapsed=0', () {
      final fsrs = Fsrs();
      final ns = fsrs.nextStates(null, 0.9, 0);

      expect(ns.again.memory.stability, closeTo(0.1104, eps));
      expect(ns.again.memory.difficulty, closeTo(6.1686, eps));
      expect(ns.again.memory.stabilityFast, closeTo(0.08832, eps));
      expect(ns.again.interval, closeTo(3.8275626e-5, epsInterval));

      expect(ns.hard.memory.stability, closeTo(2.2395, eps));
      expect(ns.hard.memory.difficulty, closeTo(5.261278, eps));
      expect(ns.hard.memory.stabilityFast, closeTo(1.7916001, eps));
      expect(ns.hard.interval, closeTo(0.5974598, epsInterval));

      expect(ns.good.memory.stability, closeTo(3.9221, eps));
      expect(ns.good.memory.difficulty, closeTo(3.5307243, eps));
      expect(ns.good.memory.stabilityFast, closeTo(3.13768, eps));
      expect(ns.good.interval, closeTo(4.7777247, epsInterval));

      expect(ns.easy.memory.stability, closeTo(11.7841, eps));
      expect(ns.easy.memory.difficulty, closeTo(1.0, eps));
      expect(ns.easy.memory.stabilityFast, closeTo(9.427279, eps));
      expect(ns.easy.interval, closeTo(53.869392, epsInterval));
    });

    test('forRating 按 1..4 映射', () {
      final fsrs = Fsrs();
      final ns = fsrs.nextStates(null, 0.9, 0);
      expect(ns.forRating(1), ns.again);
      expect(ns.forRating(2), ns.hard);
      expect(ns.forRating(3), ns.good);
      expect(ns.forRating(4), ns.easy);
      expect(() => fsrs.nextStates(null, 0.9, 0).forRating(5), throwsArgumentError);
    });
  });

  group('复习推进的单调性与合理性', () {
    test('简单 > 良好 > 困难 > 忘记 的间隔', () {
      final fsrs = Fsrs();
      final ns = fsrs.nextStates(null, 0.9, 0);
      expect(ns.easy.interval, greaterThan(ns.good.interval));
      expect(ns.good.interval, greaterThan(ns.hard.interval));
      expect(ns.hard.interval, greaterThan(ns.again.interval));
    });

    test('再次复习（有状态）稳定度随成功上升', () {
      final fsrs = Fsrs();
      final first = fsrs.nextStates(null, 0.9, 0).good.memory;
      // 5 天后再次"良好"
      final second = fsrs.step(5, 3, first, 1);
      expect(second.stability, greaterThan(first.stability));
      // 难度有界
      expect(second.difficulty, greaterThanOrEqualTo(1.0));
      expect(second.difficulty, lessThanOrEqualTo(10.0));
    });

    test('忘记会降低稳定度但不低于 S_MIN', () {
      final fsrs = Fsrs();
      final first = fsrs.nextStates(null, 0.9, 0).good.memory;
      final lapsed = fsrs.step(10, 1, first, 1);
      expect(lapsed.stability, lessThan(first.stability));
      expect(lapsed.stability, greaterThanOrEqualTo(0.01));
    });
  });

  group('可回忆度与间隔', () {
    test('t=0 时可回忆度接近 1', () {
      final fsrs = Fsrs();
      final s = fsrs.nextStates(null, 0.9, 0).good.memory;
      final r0 = fsrs.currentRetrievability(s, 0);
      expect(r0, closeTo(1.0, 0.01));
    });

    test('可回忆度随时间单调下降', () {
      final fsrs = Fsrs();
      final s = fsrs.nextStates(null, 0.9, 0).good.memory;
      double prev = 1.1;
      for (final t in [0.0, 1.0, 5.0, 20.0, 60.0]) {
        final r = fsrs.currentRetrievability(s, t);
        expect(r, lessThan(prev));
        prev = r;
      }
    });

    test('nextIntervalForState 在期望保持率下的可回忆度≈目标', () {
      final fsrs = Fsrs();
      final s = fsrs.nextStates(null, 0.9, 0).good.memory;
      const dr = 0.9;
      final interval = fsrs.nextIntervalForState(s, dr);
      final r = fsrs.currentRetrievability(s, interval);
      expect(r, closeTo(dr, 0.01));
    });
  });

  group('参数校验', () {
    test('参数个数错误抛异常', () {
      expect(() => Fsrs([1.0, 2.0]), throwsArgumentError);
    });

    test('含非有限值抛异常', () {
      final bad = List<double>.filled(kFsrs7ParamLen, 1.0);
      bad[0] = double.nan;
      expect(() => Fsrs(bad), throwsArgumentError);
    });
  });
}
