import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防回归守卫：启动时必须把"加载过设置的那个 repo"交给 repoProvider。
///
/// 曾经的真实 bug：main() 里 new 一个临时 CollectionRepo 调 loadSettings()
/// 就丢掉，而 repoProvider 又 new 了另一个从未加载设置的实例。
/// 后果是期望保持率、每日新卡/复习上限、同步服务器地址**每次重启都回到默认值**
/// —— 用户改完看起来生效（当前进程内是对的），重启就悄悄丢了，且不报任何错。
///
/// 这类"装配漏接线"编译器查不出、单测也碰不到（单测自己构造 repo），
/// 所以这里对源码做一条窄断言。改动 main.dart 的装配方式时，同步更新本测试。
void main() {
  test('main.dart 必须把加载过设置的 repo 注入 repoProvider', () {
    final src = File('lib/main.dart').readAsStringSync();

    expect(
      RegExp(r'repoProvider\.overrideWithValue\(\s*repo\s*\)').hasMatch(src),
      isTrue,
      reason: 'main() 里 loadSettings 用的 repo 实例必须经 repoProvider.overrideWithValue '
          '注入，否则 repoProvider 会另建一个未加载设置的实例，'
          '导致设置与同步地址重启后回到默认值。',
    );

    // 反向确认：不能出现"临时变量加载完就丢"的老写法。
    expect(
      RegExp(r'final\s+repo\s*=\s*CollectionRepo\(db\)').hasMatch(src),
      isFalse,
      reason: 'loadSettings 的 repo 必须是提升到作用域外的同一个实例，不能是 final 局部临时变量。',
    );
  });
}
