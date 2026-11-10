import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防回归守卫：Windows 产物路径必须与 Flutter 实际产出的目录一致。
///
/// 根因（实测）：Flutter 3.4x 的 Windows 构建产物在
/// `app\build\windows\x64\runner\Release\`，比老版本多了 `x64` 一段。
/// 而 `scripts\build-windows.ps1` 与 `.github\workflows\build.yml` 里一直写的是
/// 不带 x64 的旧路径 —— 本机 `app\build\windows\runner\` 目录**根本不存在**
/// （`ls app/build/windows/` 实测只有 `x64/`）。后果：
///  * 脚本构建成功了却报不出目录、列不出 exe；
///  * CI 的 Compress-Archive 找不到源，upload-artifact 配 `if-no-files-found: error`
///    直接把整条 Windows 流水线打挂。
///
/// 与 `android_manifest_test.dart` 同一思路：只读仓库里的文本文件，不依赖构建产物，
/// `flutter test` 里是毫秒级的；本机若真有产物就顺带核对磁盘布局。
void main() {
  group('Windows 产物路径（build 脚本与 CI 防回归）', () {
    const correct = r'build\windows\x64\runner\Release';

    test('build-windows.ps1 用的是 x64 产物路径', () {
      final src = _readRepoFile('scripts/build-windows.ps1');
      _assertUsesReleasePath(src, 'scripts/build-windows.ps1', correct);
    });

    test('CI 的打包步骤用的是 x64 产物路径', () {
      final src = _readRepoFile('.github/workflows/build.yml');
      _assertUsesReleasePath(src, '.github/workflows/build.yml', correct);
    });

    test('两处都不再出现不带 x64 的老路径', () {
      for (final path in ['scripts/build-windows.ps1', '.github/workflows/build.yml']) {
        final normalized = _releasePathsIn(_readRepoFile(path));
        for (final found in normalized) {
          expect(found, contains(r'x64\runner'),
              reason: '$path 里出现了 $found —— Flutter 3.4x 不产这个目录，'
                  'CI 的 upload-artifact 会因 if-no-files-found: error 整条挂掉');
        }
      }
    });

    test('本机若已有构建产物，Release 目录只在 x64 下（核对磁盘而非记忆）', () {
      // ⚠️ 这条第一次跑就挂掉了 CI：它原本用"找不到就 fail"的文件定位器，而干净检出
      // 里根本没有 app/build —— 本机构建过所以从没暴露。产物布局只在"构建过"的机器上
      // 才谈得上，所以这里必须用可空解析 + 直接跳过，不能当成失败。
      final located = _resolveRepoPathOrNull('app/build/windows');
      if (located == null) return;
      final windows = Directory(located);
      if (!windows.existsSync()) return;
      final stale = Directory('${windows.path}/runner/Release');
      expect(stale.existsSync(), isFalse,
          reason: '出现 app/build/windows/runner/Release 说明 Flutter 版本的产物布局又变了，'
              '本守卫与两个脚本要一起改');
    });

    test('build-windows.ps1 能被 Windows PowerShell 5.1 解析（UTF-8 BOM）', () {
      // 实测：PS 5.1 按 ANSI(CP936) 读无 BOM 文件，含中文时字符串终止符会被吃掉，
      // Parser::ParseFile 报 2 个错，脚本根本跑不起来（sync-server.ps1 有 BOM 所以没事）。
      final bytes = File(_resolveRepoPath('scripts/build-windows.ps1')).readAsBytesSync();
      expect(bytes.length, greaterThan(3));
      expect(bytes[0], 0xEF, reason: '缺 UTF-8 BOM，PS5.1 会把中文解析成坏引号');
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);
    });
  });
}

/// 把所有出现的 `build\windows\...\runner\Release` 归一化（反斜杠/正斜杠都算）后返回。
List<String> _releasePathsIn(String src) {
  final re = RegExp(r'build[/\\]windows[/\\](?:x64[/\\])?runner[/\\]Release');
  return re.allMatches(src).map((m) => m.group(0)!.replaceAll('/', r'\')).toList();
}

void _assertUsesReleasePath(String src, String label, String correct) {
  final found = _releasePathsIn(src);
  expect(found, isNotEmpty, reason: '$label 里找不到任何 build\\windows\\...\\runner\\Release 路径');
  expect(found, everyElement(contains(r'x64\runner')),
      reason: '$label 必须用 $correct，实测值：$found');
}

/// 从测试 CWD（`app/`）或仓库根定位文件；找不到就失败——守卫不能静默跳过。
String _resolveRepoPath(String relativeToRepoRoot) {
  final hit = _resolveRepoPathOrNull(relativeToRepoRoot);
  if (hit != null) return hit;
  fail('无法定位 $relativeToRepoRoot（CWD=${Directory.current.path}）');
}

/// 同上，但**找不到就返回 null**：给"只有构建过的机器上才成立"的检查用。
/// 用上面那个会 fail 的版本去探一个可能不存在的目录，干净检出上必红。
String? _resolveRepoPathOrNull(String relativeToRepoRoot) {
  final candidates = [
    '${Directory.current.path}/../$relativeToRepoRoot',
    '${Directory.current.path}/$relativeToRepoRoot',
  ];
  for (final p in candidates) {
    if (File(p).existsSync() || Directory(p).existsSync()) return p;
  }
  return null;
}

String _readRepoFile(String relativeToRepoRoot) =>
    File(_resolveRepoPath(relativeToRepoRoot)).readAsStringSync();
