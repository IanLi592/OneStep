import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/domain/providers.dart';
import '../sync/sync_screen.dart';

/// 设置页：每日新卡上限、复习上限、期望记忆保持率。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _newPerDay;
  late int _maxReviews;
  late double _retention;
  bool _initialized = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      // 读取失败则不显示版本号，不影响功能。
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final repo = ref.read(repoProvider);
      _newPerDay = repo.newCardsPerDay;
      _maxReviews = repo.maxReviewsPerDay;
      _retention = repo.desiredRetention;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('学习', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('每日新卡上限'),
                  trailing: Text('$_newPerDay', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                ),
                Slider(
                  value: _newPerDay.toDouble(),
                  min: 0, max: 100, divisions: 100,
                  label: '$_newPerDay',
                  onChanged: (v) => setState(() => _newPerDay = v.round()),
                  onChangeEnd: (_) async {
                    final repo = ref.read(repoProvider);
                    repo.newCardsPerDay = _newPerDay;
                    await repo.saveSettings();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('每日复习上限'),
                  trailing: Text('$_maxReviews', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                ),
                Slider(
                  value: _maxReviews.toDouble(),
                  min: 20, max: 500, divisions: 48,
                  label: '$_maxReviews',
                  onChanged: (v) => setState(() => _maxReviews = v.round()),
                  onChangeEnd: (_) async {
                    final repo = ref.read(repoProvider);
                    repo.maxReviewsPerDay = _maxReviews;
                    await repo.saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('记忆', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('期望记忆保持率'),
                  subtitle: const Text('越高复习越频繁，记忆越牢'),
                  trailing: Text('${(_retention * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                ),
                Slider(
                  value: _retention,
                  min: 0.70, max: 0.97, divisions: 27,
                  label: '${(_retention * 100).toStringAsFixed(0)}%',
                  onChanged: (v) => setState(() => _retention = v),
                  onChangeEnd: (_) async {
                    final repo = ref.read(repoProvider);
                    repo.desiredRetention = _retention;
                    await repo.saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('同步', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync_outlined),
              title: const Text('多设备同步'),
              subtitle: const Text('登录账号，跨设备合并学习进度'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _version.isEmpty
                  ? '跬步 Onestep · 本地优先，数据在你手中'
                  : '跬步 Onestep $_version\n本地优先，数据在你手中',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
