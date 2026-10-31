import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/collection_repo.dart';
import 'widget_updater.dart';

/// 全局数据库实例（应用启动时由 main 覆盖为真实文件库；测试可注入内存库）。
final dbProvider = Provider<OnestepDb>((ref) {
  throw UnimplementedError('在 main 中覆盖 dbProvider');
});

/// 集合仓库。
final repoProvider = Provider<CollectionRepo>((ref) {
  final db = ref.watch(dbProvider);
  return CollectionRepo(db);
});

/// 桌面小组件数据桥。
final widgetUpdaterProvider = Provider<WidgetUpdater>((ref) {
  final repo = ref.watch(repoProvider);
  return WidgetUpdater(repo);
});

/// 牌组列表。
final decksProvider = FutureProvider<List<Deck>>((ref) async {
  final repo = ref.watch(repoProvider);
  return repo.allDecks();
});

/// 某牌组今日计数。
final deckCountsProvider = FutureProvider.family<DeckCounts, String>((ref, deckId) async {
  final repo = ref.watch(repoProvider);
  return repo.deckCounts(deckId);
});

/// 某牌组待复习队列（进入学习时加载一次）。
final dueCardsProvider = FutureProvider.family<List<Card>, String>((ref, deckId) async {
  final repo = ref.watch(repoProvider);
  return repo.dueCards(deckId);
});
