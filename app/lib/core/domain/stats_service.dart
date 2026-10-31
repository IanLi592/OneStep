import '../data/database.dart';

/// 统计数据（近 7 天复习量、卡片状态分布、连续打卡天数、记忆保持率）。
class StatsService {
  StatsService(this.db);

  final OnestepDb db;

  /// 近 [days] 天每日复习次数（不含被撤销的）。返回与 [days] 等长的数组，
  /// 最后一项为今天，往前推。
  Future<List<DailyCount>> reviewActivity(int days) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logs = await (db.select(db.reviewLogs)
          ..where((l) => l.undone.equals(false)))
        .get();

    final result = <DailyCount>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final start = day.millisecondsSinceEpoch;
      final end = day.add(const Duration(days: 1)).millisecondsSinceEpoch;
      final count = logs.where((l) => l.reviewedAt >= start && l.reviewedAt < end).length;
      result.add(DailyCount(day: day, count: count));
    }
    return result;
  }

  /// 卡片状态分布。
  Future<CardDistribution> cardDistribution() async {
    final cards = await (db.select(db.cards)
          ..where((c) => c.deleted.equals(false)))
        .get();
    var newC = 0, learning = 0, review = 0, suspended = 0;
    for (final c in cards) {
      if (c.queue == -1) {
        suspended++;
      } else if (c.queue == 0) {
        newC++;
      } else if (c.queue == 1 || c.queue == 3) {
        learning++;
      } else {
        review++;
      }
    }
    return CardDistribution(newCards: newC, learning: learning, review: review, suspended: suspended);
  }

  /// 累计复习次数与平均记忆保持率（按日志：非"忘记"占比）。
  Future<ReviewSummary> reviewSummary() async {
    final logs = await (db.select(db.reviewLogs)
          ..where((l) => l.undone.equals(false)))
        .get();
    if (logs.isEmpty) return const ReviewSummary(total: 0, retention: 0, againRate: 0);
    final again = logs.where((l) => l.rating == 1).length;
    final retention = 1 - (again / logs.length);
    return ReviewSummary(total: logs.length, retention: retention, againRate: again / logs.length);
  }

  /// 连续打卡天数：从今天（或昨天）往前数有复习记录的连续天数。
  Future<int> studyStreak() async {
    final logs = await (db.select(db.reviewLogs)
          ..where((l) => l.undone.equals(false)))
        .get();
    if (logs.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = logs
        .map((l) {
          final t = DateTime.fromMillisecondsSinceEpoch(l.reviewedAt);
          return DateTime(t.year, t.month, t.day);
        })
        .toSet();

    var streak = 0;
    // 允许今天还没复习：从昨天开始数。
    var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

/// 每日复习计数。
class DailyCount {
  const DailyCount({required this.day, required this.count});
  final DateTime day;
  final int count;
}

/// 卡片状态分布。
class CardDistribution {
  const CardDistribution({
    required this.newCards,
    required this.learning,
    required this.review,
    required this.suspended,
  });
  final int newCards;
  final int learning;
  final int review;
  final int suspended;

  int get total => newCards + learning + review + suspended;
}

/// 复习汇总。
class ReviewSummary {
  const ReviewSummary({required this.total, required this.retention, required this.againRate});
  final int total;
  final double retention;
  final double againRate;
}
