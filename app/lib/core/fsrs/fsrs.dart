/// FSRS-7 间隔重复调度算法（Dart 移植）。
///
/// 干净地依据官方开源参考实现 [fsrs-rs](https://github.com/open-spaced-repetition/fsrs-rs)
/// （MIT 许可）的公式移植，用于"跬步/Onestep"的卡片调度。
///
/// 本文件只依赖 Dart 核心数学，纯计算、无 IO，便于单元测试。
/// 数值公式与官方 FSRS-7 保持一致；默认参数为官方发布值。
library;

import 'dart:math' as math;

/// FSRS-7 默认参数（34 个），取自官方 fsrs-rs `DEFAULT_PARAMETERS`。
const List<double> kFsrs7DefaultParameters = [
  0.1104, 2.2395, 3.9221, 11.7841, 6.1686, 0.6457, 3.6807, 1.9795, 0.0, 1.3826, 0.7024, 0.5999,
  0.8146, 0.6398, 1.0, 1.3207, 0.6707, 3.8668, 0.4416, 0.0934, 1.8631, 0.6162, 1.0869, 0.1567,
  0.0801, 0.2421, 0.9464, 0.1433, 0.7145, 0.0, 0.5667, 0.3734, 0.5333, 0.3048,
];

/// 参数个数（FSRS-7）。
const int kFsrs7ParamLen = 34;

// 数值边界，与官方实现一致。
const double _sMin = 0.01;
const double _sMax = 36500.0;
const double _dMin = 1.0;
const double _dMax = 10.0;
const double _drMin = 0.0001;
const double _drMax = 0.9999;
const double _minT = 1.0 / 86400.0;
const int _intervalNewtonIters = 7;
const int _bisectionIters = 50;

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// 记忆状态：稳定度(S)、难度(D)、快速稳定度(S_fast，FSRS-7 双组分特有)。
class MemoryState {
  const MemoryState({required this.stability, required this.difficulty, required this.stabilityFast});

  final double stability;
  final double difficulty;
  final double stabilityFast;

  /// 新卡（无历史）对应的零状态。
  static const MemoryState zero =
      MemoryState(stability: 0, difficulty: 0, stabilityFast: 0);

  @override
  bool operator ==(Object other) =>
      other is MemoryState &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.stabilityFast == stabilityFast;

  @override
  int get hashCode => Object.hash(stability, difficulty, stabilityFast);

  @override
  String toString() =>
      'MemoryState(S: ${stability.toStringAsFixed(4)}, D: ${difficulty.toStringAsFixed(4)}, Sfast: ${stabilityFast.toStringAsFixed(4)})';
}

/// 单个评分档位的结果：记忆状态 + 间隔(天)。
class ItemState {
  const ItemState({required this.memory, required this.interval});

  final MemoryState memory;

  /// 下次复习间隔，单位天（可为小数，<1 表示当天内）。
  final double interval;
}

/// 四个评分档位（忘记/困难/良好/简单）各自的结果。
class NextStates {
  const NextStates({required this.again, required this.hard, required this.good, required this.easy});

  final ItemState again;
  final ItemState hard;
  final ItemState good;
  final ItemState easy;

  /// 按评分(1=again..4=easy)取结果。
  ItemState forRating(int rating) => switch (rating) {
        1 => again,
        2 => hard,
        3 => good,
        4 => easy,
        _ => throw ArgumentError('rating 必须为 1..4，收到 $rating'),
      };
}

/// FSRS-7 调度器。持有参数，提供状态推进与间隔计算。
class Fsrs {
  /// 创建调度器；[parameters] 为空则用 FSRS-7 默认参数，否则必须为 34 个有限值。
  Fsrs([List<double>? parameters])
      : w = _checkAndFill(parameters) {
    // 构造即校验，_checkAndFill 已保证合法。
  }

  /// 当前生效的 34 个参数。
  final List<double> w;

  static List<double> _checkAndFill(List<double>? p) {
    if (p == null || p.isEmpty) return List<double>.from(kFsrs7DefaultParameters);
    if (p.length != kFsrs7ParamLen) {
      throw ArgumentError('FSRS-7 参数必须为 $kFsrs7ParamLen 个，收到 ${p.length}');
    }
    if (p.any((v) => v.isNaN || v.isInfinite)) {
      throw ArgumentError('FSRS 参数含非有限值');
    }
    return List<double>.from(p);
  }

  // ---------------------------------------------------------------------------
  // 初始量
  // ---------------------------------------------------------------------------

  /// 给定首次评分(1..4)的初始稳定度：S0 = w[rating-1]。
  double initStability(int rating) =>
      w[_clampInt(rating, 1, 4) - 1].clamp(_sMin, _sMax);

  /// 给定首次评分(1..4)的初始难度：D0 = w4 - exp(w5*(rating-1)) + 1。
  double initDifficulty(int rating) {
    final r = _clampInt(rating, 1, 4);
    return (w[4] - (w[5] * (r - 1)).exp() + 1).clamp(_dMin, _dMax);
  }

  // ---------------------------------------------------------------------------
  // 遗忘曲线（双组分）
  // ---------------------------------------------------------------------------

  double _fastDecayMagnitude(double sFast) =>
      (w[23] * sFast.pow(w[33] - 0.3)).clamp(0.01, 0.95);

  /// 快组分在经过 t 天、快速稳定度 sFast 下的可回忆度。
  double _fastComponentRecall(double t, double sFast) {
    final tt = t < 0 ? 0.0 : t;
    final sf = _clamp(sFast, _sMin, _sMax);
    final decay1 = -_fastDecayMagnitude(sf);
    final factor1 = ((w[25].ln() / _min(decay1, 60.0)).exp()) - 1.0;
    return (1.0 + factor1 * (tt / sf)).pow(decay1);
  }

  /// 记忆状态在经过 [t] 天后的可回忆度 R(t)。
  double forgettingCurve(double t, MemoryState state) {
    final tt = t < 0 ? 0.0 : t;
    final s = state.stability < _sMin ? _sMin : state.stability;
    final sFast = state.stabilityFast < _sMin ? _sMin : state.stabilityFast;
    final d = _clamp(state.difficulty, _dMin, _dMax);

    // 快组分
    final decay1 = -_fastDecayMagnitude(sFast);
    final factor1 = ((w[25].ln() / _min(decay1, 60.0)).exp()) - 1.0;
    final r1 = (1.0 + factor1 * (tt / sFast)).pow(decay1);

    // 慢组分
    final decay2 = -_clamp(w[24], 0.01, 0.95);
    final factor2 = w[26].pow(1.0 / decay2) - 1.0;
    final dTimescale = ((d - 5.0) * (w[32] - 0.3)).exp();
    final r2 = (1.0 + factor2 * dTimescale * (tt / s)).pow(decay2);

    // 加权
    final weight1 = w[27] * sFast.pow(-w[29]);
    final weight2 = w[28] * s.pow(w[30]) * ((d - 5.0) * (w[31] - 0.5)).exp();
    final retention = (weight1 * r1 + weight2 * r2) / (weight1 + weight2);
    return retention * (1.0 - 2e-5) + 1e-5;
  }

  /// 遗忘曲线及其对 t 的导数（供 Newton 求间隔使用）。
  (double, double) _forgettingCurveAndDerivative(double t, MemoryState state) {
    final tt = t < 0 ? 0.0 : t;
    final s = state.stability < _sMin ? _sMin : state.stability;
    final sFast = state.stabilityFast < _sMin ? _sMin : state.stabilityFast;
    final d = _clamp(state.difficulty, _dMin, _dMax);

    final decay1 = -_fastDecayMagnitude(sFast);
    final factor1 = ((w[25].ln() / _min(decay1, 60.0)).exp()) - 1.0;
    final b1 = 1.0 + factor1 * (tt / sFast);
    final r1 = b1.pow(decay1);
    final dr1 = decay1 * b1.pow(decay1 - 1.0) * factor1 / sFast;

    final decay2 = -_clamp(w[24], 0.01, 0.95);
    final factor2 = w[26].pow(1.0 / decay2) - 1.0;
    final dTimescale = ((d - 5.0) * (w[32] - 0.3)).exp();
    final b2 = 1.0 + factor2 * dTimescale * (tt / s);
    final r2 = b2.pow(decay2);
    final dr2 = decay2 * b2.pow(decay2 - 1.0) * factor2 * dTimescale / s;

    final weight1 = w[27] * sFast.pow(-w[29]);
    final weight2 = w[28] * s.pow(w[30]) * ((d - 5.0) * (w[31] - 0.5)).exp();
    final weightSum = (weight1 + weight2) < 1e-9 ? 1e-9 : (weight1 + weight2);
    final retention = (weight1 * r1 + weight2 * r2) / weightSum;
    final derivative = (weight1 * dr1 + weight2 * dr2) / weightSum;
    return (retention * (1.0 - 2e-5) + 1e-5, derivative * (1.0 - 2e-5));
  }

  // ---------------------------------------------------------------------------
  // 难度更新
  // ---------------------------------------------------------------------------

  /// 更新难度（含对 recall 的自适应与均值回归）。
  double nextDifficulty(double d, int rating, double retention) {
    final r = _clampInt(rating, 1, 4);
    var deltaD = -w[6] * (r - 3.0);
    if (r == 1) deltaD *= (retention + 0.1);
    final newD = d + (10.0 - d) * deltaD / 9.0;
    final initEasy = initDifficulty(4);
    return (initEasy * 0.01 + newD * 0.99).clamp(_dMin, _dMax);
  }

  // ---------------------------------------------------------------------------
  // 稳定度更新
  // ---------------------------------------------------------------------------

  double _stabilityForSet({
    required double lastS,
    required double lastD,
    required double retrievability,
    required int rating,
    required int start,
  }) {
    final rt = _clampInt(rating, 1, 4);
    final hardPenalty = rt == 2 ? w[start + 6] : 1.0;
    final easyBonus = rt == 4 ? w[start + 7] : 1.0;

    final newSFail = w[start + 3] *
        ((lastS + 1.0).pow(w[start + 4]) - 1.0) *
        ((1.0 - retrievability) * w[start + 5]).exp();
    final pls = _min(lastS, newSFail);

    final sinc = ((w[start] - 1.5).exp()) *
            (11.0 - lastD) *
            lastS.pow(-w[start + 1]) *
            (((1.0 - retrievability) * w[start + 2]).exp() - 1.0) *
            hardPenalty *
            easyBonus +
        1.0;
    final newSSuccess = _max(pls, lastS * sinc);

    final result = rt > 1 ? newSSuccess : pls;
    return _clamp(result, _sMin, _sMax);
  }

  /// 在给定当前状态与评分下，推进一步得到下一个状态。
  ///
  /// [deltaT] 为距上次复习的天数；[nth] 为该卡第几次复习(0 表示首评)。
  MemoryState step(double deltaT, int rating, MemoryState state, int nth) {
    final last = MemoryState(
      stability: _clamp(state.stability, _sMin, _sMax),
      difficulty: _clamp(state.difficulty, _dMin, _dMax),
      stabilityFast: _clamp(state.stabilityFast, _sMin, _sMax),
    );
    var next = _nextState(last, deltaT < 0 ? 0.0 : deltaT, rating);
    if (nth == 0 && state.stability == 0.0) {
      // 首次评分：直接用初始量。
      final rt = _clampInt(rating, 1, 4);
      final s = initStability(rt);
      next = MemoryState(
        stability: s,
        difficulty: initDifficulty(rt),
        stabilityFast: s * 0.8,
      );
    }
    return rating == 0 ? last : next;
  }

  MemoryState _nextState(MemoryState state, double deltaT, int rating) {
    final rt = _clampInt(rating, 1, 4);
    final retrievability = forgettingCurve(deltaT, state);
    final newSSlow = _stabilityForSet(
      lastS: state.stability,
      lastD: state.difficulty,
      retrievability: retrievability,
      rating: rt,
      start: 7,
    );
    final rFast = _fastComponentRecall(deltaT, state.stabilityFast);
    var newSFast = _stabilityForSet(
      lastS: state.stabilityFast,
      lastD: state.difficulty,
      retrievability: rFast,
      rating: rt,
      start: 15,
    );
    if (rt == 1) newSFast = _min(newSFast, newSSlow * 0.8);
    final newD = nextDifficulty(state.difficulty, rt, retrievability);
    return MemoryState(
      stability: newSSlow,
      difficulty: newD,
      stabilityFast: _clamp(newSFast, _sMin, _sMax),
    );
  }

  // ---------------------------------------------------------------------------
  // 间隔计算
  // ---------------------------------------------------------------------------

  /// 由记忆状态求满足期望保持率的下次间隔(天)。Newton + 二分兜底。
  double nextIntervalForState(MemoryState state, double desiredRetention) {
    final dr = _clamp(desiredRetention, _drMin, _drMax);
    if (dr >= _drMax) return 0.0;

    final st = MemoryState(
      stability: _clamp(state.stability, _sMin, _sMax),
      difficulty: _clamp(state.difficulty, _dMin, _dMax),
      stabilityFast: _clamp(state.stabilityFast, _sMin, _sMax),
    );
    final minLogT = _minT.ln();
    final maxLogT = _sMax.ln();
    var logT = _max(_max(st.stability, st.stabilityFast), _minT).ln();

    for (var i = 0; i < _intervalNewtonIters; i++) {
      logT = _clamp(logT, minLogT, maxLogT);
      final t = _clamp(logT.exp(), _minT, _sMax);
      final (retrievability, derivative) = _forgettingCurveAndDerivative(t, st);
      final dfdu = _min(derivative * t, -1e-12);
      final step = _clamp((retrievability - dr) / dfdu, -4.0, 4.0);
      logT -= step;
      if (logT.isNaN || logT.isInfinite) {
        return _bisectionInterval(st, dr);
      }
    }

    final interval = _clamp(logT.exp(), 0.0, _sMax);
    final retrievability = forgettingCurve(interval, st);
    if (retrievability.isFinite && (retrievability - dr).abs() <= 1e-3) {
      return interval;
    }
    return _bisectionInterval(st, dr);
  }

  double _bisectionInterval(MemoryState state, double desiredRetention) {
    var low = 0.0;
    var high = _max(_max(state.stability, state.stabilityFast), 1.0);
    while (forgettingCurve(high, state) > desiredRetention && high < _sMax) {
      high = _min(high * 2.0, _sMax);
    }
    for (var i = 0; i < _bisectionIters; i++) {
      final mid = (low + high) * 0.5;
      if (forgettingCurve(mid, state) > desiredRetention) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return _clamp((low + high) * 0.5, 0.0, _sMax);
  }

  /// 给定稳定度（忽略难度/快速分量的简化版），求下次间隔(天)。
  double nextInterval(double? stability, double desiredRetention, int rating) {
    final s = stability ?? initStability(rating);
    return nextIntervalForState(
      MemoryState(stability: s, difficulty: 5.0, stabilityFast: s),
      desiredRetention,
    );
  }

  // ---------------------------------------------------------------------------
  // 便捷入口
  // ---------------------------------------------------------------------------

  /// 四个评分档位的结果。[current] 为 null 表示新卡。
  NextStates nextStates(MemoryState? current, double desiredRetention, double elapsedDays) {
    final MemoryState cur;
    final int nth;
    if (current != null) {
      cur = current;
      nth = 1;
    } else {
      cur = MemoryState.zero;
      nth = 0;
    }
    ItemState build(int rating) {
      final memory = step(elapsedDays, rating, cur, nth);
      final interval = nextIntervalForState(memory, desiredRetention);
      return ItemState(memory: memory, interval: interval);
    }

    return NextStates(again: build(1), hard: build(2), good: build(3), easy: build(4));
  }

  /// 当前记忆状态下的可回忆度 R(t)。
  double currentRetrievability(MemoryState state, double daysElapsed) =>
      forgettingCurve(daysElapsed < 0 ? 0.0 : daysElapsed, state);
}

// 小工具：避免与 dart:math 混淆，且保持与 Rust 一致的取小/取大语义。
double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

extension on double {
  double exp() => _exp(this);
  double ln() => _ln(this);
  double pow(double e) => _pow(this, e);
}

// 通过 dart:math 实现，放在此处便于集中管理。
double _exp(double x) => math.exp(x);
double _ln(double x) => math.log(x);
double _pow(double x, double e) => math.pow(x, e).toDouble();
