import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database.dart' as data;
import '../../../core/domain/collection_repo.dart';
import '../../../core/domain/providers.dart';
import '../../../core/sync/sync_client.dart';
import '../../../shared/theme/palette.dart';
import '../../../shared/widgets/ink.dart';

/// 同步设置：服务器地址、账号登录/注册、手动同步、上次同步结果。
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _serverFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  SyncClient? _client;
  bool _busy = false;
  String? _status;
  bool _statusOk = false;
  int _cursor = 0;

  /// [_cursor] 所归属的账号。用它判断"这次认证是不是换了账号"。
  String? _sessionAccountId;

  @override
  void initState() {
    super.initState();
    // 回填上次保存的地址/账号/密钥/游标 —— 手机上进一次就记住，下次不用重填。
    final repo = _repo;
    _serverCtrl.text = repo.syncServerUrl;
    _userCtrl.text = repo.syncUsername;
    _passCtrl.text = repo.syncSecret;
    _cursor = repo.syncCursor;
    // 记住这份游标是属于哪个账号的：换账号时要据此把它归零（见 _adoptSession）。
    _sessionAccountId = repo.syncAccountId;

    // 沿用上次会话：这里不联网校验——每次进页面就发请求，服务端没起时
    // 会莫名冒出一个错误。真正的失效（服务端重启导致 token 作废）会在首次
    // 同步时收到 401，由 _sync 捕获 SyncAuthException 后自动重登并重试。
    if (repo.syncToken.isNotEmpty) {
      _client = SyncClient(repo, baseUrl: repo.syncServerUrl)
        ..restoreSession(repo.syncToken, accountId: repo.syncAccountId);
    }

    // 失焦即存：改完地址点开别的输入框，值就已经落库了。
    // （不在 dispose 里写库——那时 ref 可能已失效，异步写还会跑到测试
    //  tearDown 之后，留下"pending timer / 已关闭数据库"之类的假失败。）
    for (final f in [_serverFocus, _userFocus, _passFocus]) {
      f.addListener(() {
        if (!f.hasFocus && mounted) _persistInputs();
      });
    }
  }

  @override
  void dispose() {
    _serverFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  CollectionRepo get _repo => ref.read(repoProvider);

  /// 把界面上的同步设置（含会话 token）写回本机。
  ///
  /// 在每次动作开始时也调用一次：这样即使登录失败（地址填错、服务端没起），
  /// 用户改的地址也已经存下，下次进来不用重填。
  Future<void> _persistInputs() async {
    final repo = _repo;
    repo.syncServerUrl = _serverCtrl.text.trim();
    repo.syncUsername = _userCtrl.text.trim();
    repo.syncSecret = _passCtrl.text;
    repo.syncCursor = _cursor;
    repo.syncToken = _client?.token ?? '';
    repo.syncAccountId = _client?.accountId ?? '';
    await repo.saveSyncSettings();
  }

  /// 把一次认证成功并入界面状态：账号变了就把游标归零。
  ///
  /// 三条认证路径（注册、登录、静默重登）都必须走这里，少一条就会留下
  /// "换了账号但仍用旧账号的游标"的死局 —— 表现为同步永远"推送 0 条、
  /// 应用 0 条"却毫不报错。判定逻辑在 nextCursorAfterAuth（有单测）。
  void _adoptSession(SyncClient c) {
    final next = nextCursorAfterAuth(
      previousAccountId: _sessionAccountId,
      accountId: c.accountId,
      currentCursor: _cursor,
    );
    if (c.accountId != null && c.accountId!.isNotEmpty) {
      _sessionAccountId = c.accountId;
    }
    if (next != _cursor && mounted) setState(() => _cursor = next);
  }

  /// 用已记住的账号+密钥静默登录（不需要用户再点「登录」）。
  Future<SyncClient> _loginSilently() async {
    final user = _userCtrl.text.trim();
    final secret = _passCtrl.text;
    if (user.isEmpty || secret.isEmpty) {
      throw SyncException('还没有记住的账号，请先点「登录」或「注册」一次。');
    }
    final c = SyncClient(_repo, baseUrl: _serverCtrl.text.trim());
    await c.login(user, secret);
    c.setDeviceId(await _deviceId());
    await c.registerDevice(name: 'Onestep');
    _adoptSession(c);
    if (mounted) setState(() => _client = c);
    return c;
  }

  /// 拿到一个已认证的客户端：优先沿用上次会话，没有就静默重登。
  Future<SyncClient> _ensureAuthed() async {
    final c = _client;
    if (c != null && c.isAuthed) {
      c.setDeviceId(await _deviceId());
      return c;
    }
    return _loginSilently();
  }

  Future<void> _doSync(SyncClient c) async {
    final res = await c.sync(sinceCursor: _cursor);
    if (!mounted) return;
    setState(() {
      _cursor = res.cursor;
      _status = '同步完成：推送 ${res.pushed} 条，应用 ${res.applied} 条';
      _statusOk = true;
    });
    // 游标与 token 要立刻落库，否则下次启动又从头开始。
    await _persistInputs();
    ref.invalidate(decksProvider);
  }

  Future<void> _run(Future<void> Function() action, String doing) async {
    setState(() {
      _busy = true;
      _status = doing;
      _statusOk = false;
    });
    try {
      await _persistInputs();
      await action();
    } on SyncException catch (e) {
      setState(() {
        _status = e.message;
        _statusOk = false;
      });
    } catch (e) {
      setState(() {
        _status = '$e';
        _statusOk = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() => _run(() async {
        final c = SyncClient(_repo, baseUrl: _serverCtrl.text.trim());
        await c.register(_userCtrl.text.trim(), _passCtrl.text);
        c.setDeviceId(await _deviceId());
        await c.registerDevice(name: 'Onestep');
        _adoptSession(c);
        setState(() {
          _client = c;
          _status = '已注册并配对本机设备';
          _statusOk = true;
        });
        await _persistInputs();
      }, '正在注册…');

  Future<void> _login() => _run(() async {
        final c = SyncClient(_repo, baseUrl: _serverCtrl.text.trim());
        await c.login(_userCtrl.text.trim(), _passCtrl.text);
        c.setDeviceId(await _deviceId());
        await c.registerDevice(name: 'Onestep');
        _adoptSession(c);
        setState(() {
          _client = c;
          _status = '已登录并配对本机设备，下次可直接同步';
          _statusOk = true;
        });
        await _persistInputs();
      }, '正在登录…');

  /// 同步：先保证有会话；若服务端 token 已失效（重启过），自动重登再试一次。
  Future<void> _sync() => _run(() async {
        final c = await _ensureAuthed();
        try {
          await _doSync(c);
        } on SyncAuthException {
          setState(() => _client = null);
          final fresh = await _loginSilently();
          await _doSync(fresh);
        }
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
    final p = InkPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('多设备同步')),
      body: InkPage(
        children: [
          InkSection(
            title: '连接',
            padding: const EdgeInsets.only(bottom: InkTokens.s2),
            // 登录状态常驻可见，不用点进去试探。
            trailing: InkChip(
              label: (_client?.isAuthed ?? false)
                  ? '已登录 ${_userCtrl.text.trim()}'
                  : '未登录',
              icon: (_client?.isAuthed ?? false)
                  ? Icons.lock_open
                  : Icons.lock_outline,
              color: (_client?.isAuthed ?? false) ? p.pine : p.ink3,
              dense: true,
            ),
          ),
          InkCard(
            raise: false,
            padding: const EdgeInsets.all(InkTokens.s4),
            child: Column(
              children: [
                TextField(
                  controller: _serverCtrl,
                  focusNode: _serverFocus,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '同步服务器地址',
                    hintText: 'http://192.168.1.10:8787',
                  ),
                ),
                const SizedBox(height: InkTokens.s3),
                TextField(
                  controller: _userCtrl,
                  focusNode: _userFocus,
                  decoration: const InputDecoration(labelText: '账号'),
                ),
                const SizedBox(height: InkTokens.s3),
                TextField(
                  controller: _passCtrl,
                  focusNode: _passFocus,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码 / 密钥'),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: InkTokens.s4),
                Row(
                  children: [
                    Expanded(
                      child: InkButton(
                        label: '登录',
                        tone: InkTone.outline,
                        onPressed: _busy ? null : _login,
                      ),
                    ),
                    const SizedBox(width: InkTokens.s3),
                    Expanded(
                      child: InkButton(
                        label: '注册',
                        onPressed: _busy ? null : _register,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: InkTokens.s3),
                InkButton(
                  label: _busy ? '同步中…' : '立即同步',
                  icon: Icons.sync,
                  tone: InkTone.pale,
                  // 不再要求先点登录：有记住的账号就直接静默登录后同步，
                  // token 失效也会自动续一次。
                  onPressed: _busy ? null : _sync,
                ),
              ],
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: InkTokens.s4),
            _statusCard(p),
          ],
          const SizedBox(height: InkTokens.s4),
          InkCard(
            raise: false,
            padding: const EdgeInsets.all(InkTokens.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: p.ink3),
                const SizedBox(width: InkTokens.s3),
                Expanded(
                  child: Text(
                    '地址、账号与登录状态都会记住：重启应用后直接点"立即同步"即可，'
                    '服务端重启导致登录失效时也会自动重新登录一次。\n'
                    '手机连电脑自建服务端时，地址要填电脑在虚拟机网卡上的 IP'
                    '（Windows 用 ipconfig 查 vEthernet 适配器），不能填 127.0.0.1。\n'
                    '离线也能正常学习，联网时点"立即同步"即可跨设备合并；'
                    '冲突按"后写胜出"自动合并，不会静默丢数据。',
                    style: TextStyle(fontSize: 12.5, height: 1.7, color: p.ink2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 同步结果：成功用松绿描边、失败用朱砂，并把错误原文留着方便排查。
  Widget _statusCard(InkPalette p) {
    final color = _statusOk ? p.pine : (_busy ? p.ink2 : p.cinnabar);
    return InkCard(
      raise: false,
      borderColor: color.withValues(alpha: 0.5),
      background: color.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(
          horizontal: InkTokens.s4, vertical: InkTokens.s3),
      child: Row(
        children: [
          Icon(
            _statusOk
                ? Icons.check_circle_outline
                : (_busy ? Icons.hourglass_top : Icons.error_outline),
            size: 19,
            color: color,
          ),
          const SizedBox(width: InkTokens.s3),
          Expanded(
            child: Text(
              _status ?? '',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
