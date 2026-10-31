import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/database.dart';
import 'core/domain/collection_repo.dart';
import 'core/domain/providers.dart';
import 'features/deck/deck_list_screen.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = OnestepDb(openConnection());
  // 建表 + 种子数据（默认牌组与笔记类型）。
  await db.seedDefaults();
  // 恢复上次保存的设置项（新卡/复习上限、期望保持率）。
  final repo = CollectionRepo(db);
  await repo.loadSettings();

  runApp(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: const OnestepApp(),
    ),
  );
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
      home: const DeckListScreen(),
    );
  }
}
