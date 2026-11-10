import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防回归守卫：release 包必须自己声明 INTERNET 权限。
///
/// 根因（2026-11-01 实机踩到）：`flutter create` 生成的模板只把
/// `android.permission.INTERNET` 写进 `debug/` 和 `profile/` 两个 manifest
/// （给 Dart VM service 用），`main/AndroidManifest.xml` 里从来没有。
/// 后果是 debug 包联网正常，**release 包没有 INTERNET 权限时 Android 内核在
/// socket 层直接拒绝 connect()**，表现为：
///
///   ClientException with SocketException: Connection failed
///   (OS Error: Operation not permitted, errno = 1)
///
/// 症状长得极像"防火墙拦了/服务端没起",但服务端 0.0.0.0 监听且 curl /health
/// 通,极易误判(本仓库 commit f820db9 就误判成明文 HTTP 被拦,加了
/// usesCleartextTraffic —— 对 dart:io 原生 socket 无效,因为这条路径根本不走
/// Java 的 NetworkSecurityPolicy)。
///
/// 本守卫只读源文件、不依赖构建产物,所以 `flutter test` 里是毫秒级的。
void main() {
  group('Android main manifest 联网权限（release 包防回归）', () {
    test('main/AndroidManifest.xml 声明了 android.permission.INTERNET', () {
      final manifest = _readMainManifest();
      expect(
        RegExp(r'<uses-permission\s+android:name="android\.permission\.INTERNET"').hasMatch(manifest),
        isTrue,
        reason: 'release 包缺 INTERNET 权限会导致同步登录报 '
            'errno=1 Operation not permitted。必须声明在 main/（不能只放 debug/）。',
      );
    });

    test('INTERNET 声明是 <manifest> 的直接子元素，不在 <application> 内部', () {
      final manifest = _readMainManifest();
      final permIdx = manifest.indexOf('android.permission.INTERNET');
      final appIdx = manifest.indexOf('<application');
      expect(permIdx, greaterThanOrEqualTo(0), reason: '未找到 INTERNET 权限声明');
      expect(appIdx, greaterThanOrEqualTo(0), reason: '未找到 <application> 标签');
      // <uses-permission> 必须是 <manifest> 的直接子元素；写进 <application>
      // 内部会被 aapt 静默忽略，权限等于没申请。
      expect(permIdx, lessThan(appIdx),
          reason: '<uses-permission> 必须出现在 <application> 之前（作为 manifest 直接子元素）。');
    });

    test('INTERNET 只出现在 main/，不依赖 debug/profile manifest 兜底', () {
      // debug/ 与 profile/ 里有 INTERNET 是模板自带的，它会让 debug 包"看起来正常"，
      // 正是这种不对称让 bug 溜到 release 才暴露。这里显式记录三份 manifest 的现状。
      final main = _readMainManifest();
      final debug = _readManifestBySuffix('debug');
      final profile = _readManifestBySuffix('profile');
      expect(main, contains('android.permission.INTERNET'));
      expect(debug, contains('android.permission.INTERNET'));
      expect(profile, contains('android.permission.INTERNET'));
    });
  });
}

/// 从测试工作目录（flutter test 的 CWD 是包根 app/）向上定位仓库根，
/// 读 main manifest。定位不到就直接失败——守卫不能静默跳过。
String _readMainManifest() {
  final rel = 'android/app/src/main/AndroidManifest.xml';
  final f = File(_resolveFromPackageRoot(rel));
  expect(f.existsSync(), isTrue, reason: '找不到 $f');
  return _stripXmlComments(f.readAsStringSync());
}

String _readManifestBySuffix(String variant) => _stripXmlComments(
    File(_resolveFromPackageRoot('android/app/src/$variant/AndroidManifest.xml'))
        .readAsStringSync());

/// 剥掉 XML 注释后再匹配：否则把 `<uses-permission .../>` 整行注释掉就能骗过守卫
/// （字符串还在文件里，正则照样命中），守卫等于没有。
String _stripXmlComments(String src) => src.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// 依次尝试 app/ 与仓库根两种 CWD，返回第一个存在的绝对路径。
String _resolveFromPackageRoot(String relativeToAndroid) {
  final cwd = Directory.current.path;
  final candidates = [cwd, '$cwd/app'];
  for (final base in candidates) {
    final p = '$base/$relativeToAndroid';
    if (File(p).existsSync()) return p;
  }
  // 兜底：从当前目录逐级向上找 app/android 或 android。
  var dir = Directory.current.absolute;
  for (var i = 0; i < 5; i++) {
    for (final prefix in ['', '/app']) {
      final p = '${dir.path}$prefix/$relativeToAndroid';
      if (File(p).existsSync()) return p;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('无法定位 $relativeToAndroid（CWD=${Directory.current.path}）');
}
