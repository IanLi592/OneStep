import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database.dart' as data;
import '../../../core/domain/collection_repo.dart';
import '../../../core/sync/sync_client.dart';
import '../../../core/domain/providers.dart';

/// 同步设置：服务器地址、账号登录/注册、手动同步、上次同步状态。
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _serverCtrl = TextEditingController(text: 'http://127.0.0.1:8787');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  SyncClient? _client;
  bool _busy = false;
  String? _status;
  int _cursor = 0;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  CollectionRepo get _repo => ref.read(repoProvider);

  Future<void> _run(Future<void> Function() action, String doing) async {
    setState(() { _busy = true; _status = doing; });
    try {
      await action();
    } on SyncException catch (e) {
      setState(() => _status = '❌ ${e.message}');
    } catch (e) {
      setState(() => _status = '❌ $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _register() => _run(() async {
        final c = SyncClient(_repo, baseUrl: _serverCtrl.text.trim());
        await c.register(_userCtrl.text.trim(), _passCtrl.text);
        c.setDeviceId(await _deviceId());
        await c.registerDevice(name: 'Onestep');
        setState(() { _client = c; _status = '✅ 已注册并配对设备'; });
      }, '正在注册…');

  Future<void> _login() => _run(() async {
        final c = SyncClient(_repo, baseUrl: _serverCtrl.text.trim());
        await c.login(_userCtrl.text.trim(), _passCtrl.text);
        c.setDeviceId(await _deviceId());
        await c.registerDevice(name: 'Onestep');
        setState(() { _client = c; _status = '✅ 已登录并配对设备'; });
      }, '正在登录…');

  Future<void> _sync() => _run(() async {
        final c = _client;
        if (c == null) throw SyncException('请先登录');
        final res = await c.sync(sinceCursor: _cursor);
        setState(() {
          _cursor = res.cursor;
          _status = '✅ 同步完成：推送 ${res.pushed}，应用 ${res.applied}';
        });
        // 刷新本地牌组视图。
        ref.invalidate(decksProvider);
      }, '正在同步…');

  /// 本机设备 id：存在集合配置里，保证跨次启动稳定。
  Future<String> _deviceId() async {
    final db = ref.read(dbProvider);
    final row = await (db.select(db.collectionConfigs)
          ..where((t) => t.key.equals('device_id')))
        .getSingleOrNull();
    if (row != null) return row.value;
    final id = 'dev-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    await db.into(db.collectionConfigs).insert(data.CollectionConfigsCompanion.insert(
          key: 'device_id',
          value: id,
        ));
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('多设备同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _serverCtrl,
            decoration: const InputDecoration(labelText: '同步服务器地址', hintText: 'http://host:8787'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(labelText: '账号'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码/密钥'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : _login, child: const Text('登录'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _busy ? null : _register, child: const Text('注册'))),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_busy || _client == null) ? null : _sync,
            icon: const Icon(Icons.sync),
            label: Text(_busy ? '同步中…' : '立即同步'),
          ),
          const SizedBox(height: 20),
          if (_status != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_status!, style: TextStyle(color: scheme.onSurface)),
              ),
            ),
          const SizedBox(height: 16),
          Text('提示：离线也能正常学习，联网时点"立即同步"即可跨设备合并。'
              '冲突按"后写胜出"自动合并，不会静默丢数据。',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}
