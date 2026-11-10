import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../card_edit/add_card_sheet.dart';
import '../deck/deck_list_screen.dart';
import '../me/me_screen.dart';
import '../stats/stats_screen.dart';

/// 应用外壳：底部导航 首页 / 添加 / 统计 / 我的。
///
/// 「添加」是一个**动作**而不是页面：点它弹出新建卡片弹层，选中态留在当前 tab，
/// 所以 IndexedStack 里给它留了一个永不显示的占位槽（下标 1）。
/// 这样首页与详情页的右上角就不再需要「+」图标了。
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  /// 当前目的地下标：0=首页，2=统计，3=我的（1 是"添加"动作，不会停留）。
  int _index = 0;

  void _onSelected(int i) {
    if (i == 1) {
      showAddCardSheet(context);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          SizedBox.shrink(), // 「添加」占位，永不被选中
          StatsScreen(),
          MeScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '添加',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
