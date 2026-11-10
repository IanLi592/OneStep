import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/database.dart';
import 'core/domain/collection_repo.dart';
import 'core/domain/providers.dart';
import 'features/shell/root_shell.dart';
import 'shared/quote_carousel.dart' show appRouteObserver;
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 数据库初始化失败时不再静默崩溃（双击无反应），改为展示错误窗口。
  OnestepDb? db;
  CollectionRepo? repo;
  Object? initError;
  StackTrace? initStack;
  try {
    db = OnestepDb(openConnection());
    // 建表 + 种子数据（默认牌组与笔记类型）。
    await db.seedDefaults().timeout(const Duration(seconds: 15));
    // 恢复上次保存的设置项（新卡/复习上限、期望保持率、同步地址）。
    //
    // 关键：这个 repo 必须交给 repoProvider。曾经这里是 new 一个临时实例、
    // loadSettings 完就丢弃，而 repoProvider 又 new 了另一个"从未加载设置"的
    // 实例 -> 期望保持率与每日上限每次重启都回到默认值。
    repo = CollectionRepo(db);
    await repo.loadSettings().timeout(const Duration(seconds: 10));
  } catch (e, st) {
    initError = e;
    initStack = st;
    _logError(e, st);
  }

  if (db == null || repo == null || initError != null) {
    // 展示错误窗口，让用户能看到失败原因，而不是"没反应"。
    runApp(InitErrorApp(
      error: (initError ?? '未知错误').toString(),
      stack: initStack,
    ));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        repoProvider.overrideWithValue(repo),
      ],
      child: const OnestepApp(),
    ),
  );
}

/// 把初始化错误写到 exe 旁边的日志文件，便于诊断。
void _logError(Object error, StackTrace stack) {
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final log = File('$exeDir${Platform.pathSeparator}onestep-error.log');
    log.writeAsStringSync(
      '${DateTime.now()}\n$error\n$stack\n',
      mode: FileMode.append,
    );
    stderr.writeln('[onestep] init failed, log: ${log.path}');
    stderr.writeln('$error');
  } catch (_) {
    // 日志失败不影响展示错误窗口。
  }
}

class OnestepApp extends StatelessWidget {
  const OnestepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '跬步 Onestep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // 注册路由观察器:标语轮播靠它监听"进入/退回首页"切换。
      navigatorObservers: [appRouteObserver],
      home: const RootShell(),
    );
  }
}

/// 初始化失败时的错误窗口：显示错误信息与日志路径。
class InitErrorApp extends StatelessWidget {
  const InitErrorApp({super.key, required this.error, this.stack});

  final String error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '跬步 Onestep - 启动失败',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('启动失败')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('应用初始化失败，详细原因如下：',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      '$error\n\n${stack ?? ''}',
                      style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('详细日志已写入 exe 旁的 onestep-error.log',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
