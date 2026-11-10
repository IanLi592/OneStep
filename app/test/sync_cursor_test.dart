import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/sync/sync_client.dart';

/// 换账号必须把同步游标归零（bug 修复的回归守卫）。
///
/// 真实事故（2026-11-03）：服务端早期是纯内存的，重启就清空全部账号与记录。
/// 用户于是只能重新注册，拿到一个全新的 accountId；但界面里的游标还是旧账号
/// 推进出来的高值，于是
///   · `_collectLocalChanges` 只挑 version > 游标 的本地记录 → 推送 0 条；
///   · 服务端 pull 只返回新账号名下的记录 → 应用 0 条；
///   · 界面显示"同步完成：推送 0 条，应用 0 条"，看着像正常，实际永远同步不动。
/// 判定逻辑抽成纯函数 nextCursorAfterAuth，三条认证路径统一调用 _adoptSession。
void main() {
  group('nextCursorAfterAuth', () {
    test('同一账号：保留游标，增量继续', () {
      expect(
        nextCursorAfterAuth(
          previousAccountId: 'acct_a',
          accountId: 'acct_a',
          currentCursor: 1793710630758,
        ),
        1793710630758,
      );
    });

    test('换账号：游标归零（旧游标对新账号无意义）', () {
      expect(
        nextCursorAfterAuth(
          previousAccountId: 'acct_a',
          accountId: 'acct_b',
          currentCursor: 1793710630758,
        ),
        0,
        reason: '不归零就会"推送 0 条、应用 0 条"地空转，永远同步不动。',
      );
    });

    test('首次绑定账号：归零', () {
      expect(
        nextCursorAfterAuth(
          previousAccountId: null,
          accountId: 'acct_b',
          currentCursor: 999,
        ),
        0,
      );
      expect(
        nextCursorAfterAuth(
          previousAccountId: '',
          accountId: 'acct_b',
          currentCursor: 999,
        ),
        0,
      );
    });

    test('认证没拿到账号 id：绝不清零（一次失败不能毁掉进度）', () {
      expect(
        nextCursorAfterAuth(
          previousAccountId: 'acct_a',
          accountId: null,
          currentCursor: 123,
        ),
        123,
      );
      expect(
        nextCursorAfterAuth(
          previousAccountId: 'acct_a',
          accountId: '',
          currentCursor: 123,
        ),
        123,
      );
    });
  });

  // 装配守卫：纯函数对了但没被调用，等于没修。编译器与上面的单测都碰不到
  // "三条认证路径漏接一条"这种问题，所以照 main_wiring_test.dart 的做法
  // 对源码做窄断言。改认证流程时同步更新这里。
  group('sync_screen.dart 装配守卫', () {
    final src = File('lib/features/sync/sync_screen.dart').readAsStringSync();

    test('_adoptSession 必须真的用 nextCursorAfterAuth 决定游标', () {
      expect(
        RegExp(r'void _adoptSession\(SyncClient c\)[\s\S]{0,600}?nextCursorAfterAuth\(')
            .hasMatch(src),
        isTrue,
        reason: '_adoptSession 必须调用 nextCursorAfterAuth，不能自己拍脑袋归零。',
      );
    });

    test('注册、登录、静默重登三条路径都要调 _adoptSession', () {
      final calls = RegExp(r'_adoptSession\(c\)').allMatches(src).length;
      expect(calls, 3, reason: '少一条路径，那条路径就会带着旧账号的游标继续跑。');
    });

    test('initState 必须把持久化游标与它所属的账号一起读出来', () {
      expect(
        RegExp(r'_cursor = repo\.syncCursor;').hasMatch(src),
        isTrue,
        reason: '游标要从库里读回来。',
      );
      expect(
        RegExp(r'_sessionAccountId = repo\.syncAccountId;').hasMatch(src),
        isTrue,
        reason: '不记录"这份游标属于哪个账号"，就无法判断这次认证是不是换了账号。',
      );
    });

    test('_persistInputs 仍要把游标落库，否则归零结果下次启动又变回旧值', () {
      expect(
        RegExp(r'repo\.syncCursor = _cursor;').hasMatch(src),
        isTrue,
      );
    });
  });
}
