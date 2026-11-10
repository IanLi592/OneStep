import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'stats_service.dart';

export 'stats_service.dart';

/// 统计服务。
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// 近 7 天复习活动。
final reviewActivityProvider = FutureProvider<List<DailyCount>>((ref) async {
  final stats = ref.watch(statsServiceProvider);
  return stats.reviewActivity(7);
});

/// 卡片状态分布。
final cardDistributionProvider = FutureProvider<CardDistribution>((ref) async {
  final stats = ref.watch(statsServiceProvider);
  return stats.cardDistribution();
});

/// 复习汇总（累计次数、保持率）。
final reviewSummaryProvider = FutureProvider<ReviewSummary>((ref) async {
  final stats = ref.watch(statsServiceProvider);
  return stats.reviewSummary();
});

/// 连续打卡天数。
final studyStreakProvider = FutureProvider<int>((ref) async {
  final stats = ref.watch(statsServiceProvider);
  return stats.studyStreak();
});

/// 今日已作答次数（首页今日进度环的分子）。
final todayReviewCountProvider = FutureProvider<int>((ref) async {
  final stats = ref.watch(statsServiceProvider);
  return stats.todayReviewCount();
});
