import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'collection_repo.dart';

/// 桌面小组件数据桥：把"今日待复习总数"推给 Android 小组件。
///
/// 通过 MethodChannel "onestep/widget" 调用原生 MainActivity，
/// 由其写入小组件读取的 SharedPreferences 并广播刷新。
/// 仅 Android 生效；其它平台静默跳过。
class WidgetUpdater {
  WidgetUpdater(this.repo);

  final CollectionRepo repo;
  static const _channel = MethodChannel('onestep/widget');

  /// 计算所有牌组今日待复习总数（新卡 + 学习中 + 到期复习）。
  Future<int> totalDue() async {
    final decks = await repo.allDecks();
    var total = 0;
    for (final d in decks) {
      final counts = await repo.deckCounts(d.id);
      total += counts.total;
    }
    return total;
  }

  /// 推送当前待复习总数到小组件（非 Android 或出错时静默，不影响主流程）。
  Future<void> push() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final due = await totalDue();
      await _channel.invokeMethod('updateDueCount', {'due': due});
    } catch (_) {
      // 小组件更新失败不影响应用功能。
    }
  }
}
