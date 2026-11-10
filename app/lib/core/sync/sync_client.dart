import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, JsonKey;
import 'package:http/http.dart' as http;

import '../data/database.dart';
import '../domain/collection_repo.dart';

/// 同步客户端：连接自建同步服务端，做差异推送/拉取。
///
/// 协议（与 server/src/index.js 对应）：
///   POST /register { username, secret } -> { token, accountId }
///   POST /login    { username, secret } -> { token, accountId }
///   POST /device   (Bearer) { deviceId, name } -> { device }
///   POST /sync     (Bearer) { deviceId, changes[], sinceCursor } -> { push, changed, cursor }
///
/// 记录级 LWW：每条记录带 version（毫秒时间戳），服务端保留更高的 version。
/// 客户端把本地改动打包推送，再拉取服务端比本地游标新的所有变更并应用。
class SyncClient {
  SyncClient(this.repo,
      {required this.baseUrl,
      http.Client? client,
      this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final CollectionRepo repo;
  final String baseUrl;
  final http.Client _client;

  /// 单次请求超时。
  ///
  /// 必须有：地址填错（例如在应用宝这类 Hyper-V 虚拟机里填了模拟器专用的
  /// 10.0.2.2）时，TCP 连不出去也无人拒绝，没有超时的话界面会永远停在
  /// "正在登录…"，用户完全无从判断是卡住还是在慢慢来。
  final Duration timeout;

  String? _token;
  String? _accountId;
  String _deviceId = 'unknown';

  bool get isAuthed => _token != null;

  /// 当前会话 token（供上层持久化，重启后可 restoreSession 续用）。
  String? get token => _token;

  /// 当前账号 id。
  String? get accountId => _accountId;

  /// 沿用上次登录的会话（不联网校验，真正的有效性在首次请求时才知道；
  /// 若服务端已重启导致 token 失效，请求会抛 [SyncAuthException] 触发上层重登）。
  void restoreSession(String? token, {String? accountId}) {
    _token = (token == null || token.isEmpty) ? null : token;
    _accountId = accountId;
  }

  /// 设置本机设备 id（持久化后由调用方注入）。
  void setDeviceId(String id) => _deviceId = id;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// 统一的 POST：把超时与底层 socket 错误翻译成能照着排查的中文提示。
  Future<http.Response> _post(String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final headers = auth ? _authHeaders : const {'Content-Type': 'application/json'};
    try {
      return await _client
          .post(_u(path), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw SyncException(
        '连接超时（${timeout.inSeconds} 秒无响应）：$baseUrl 不可达。\n'
        '多半是地址填错——虚拟机里 127.0.0.1 指向的是虚拟机自己，'
        '应填宿主机在虚拟网卡上的地址（Windows 用 ipconfig 查 vEthernet 适配器的 IPv4）。'
        '也可能是服务端没启动或端口没放行。',
      );
    } on SocketException catch (e) {
      // http 1.6 的连接失败抛 _ClientSocketException，它同时实现 ClientException
      // 与 SocketException。Dart 取第一个匹配的 on 子句，所以这条必须排在
      // ClientException 之前，否则拿不到 osError/errno（当初 errno=1 那条
      // 看不懂的报错，就是因为没在这里被翻译成可排查的提示）。
      // 顺序回归由 test/sync_client_test.dart 的「errno 会被翻译进提示」锁死。
      final os = e.osError;
      throw SyncException(
        '连不上 $baseUrl：${os?.message ?? e.message}'
        '${os != null ? '（errno=${os.errorCode}）' : ''}。\n'
        'errno=1 通常是应用缺 INTERNET 权限；errno=10061 是对方端口没在听；'
        '超时不返回则是地址不可达。请核对服务器地址与服务端状态。',
      );
    } on http.ClientException catch (e) {
      throw SyncException('请求 $baseUrl 失败：${e.message}。\n请确认服务端已启动且版本与同步协议匹配。');
    }
  }

  /// 注册新账号。
  Future<void> register(String username, String secret) async {
    final res = await _post('/register', {'username': username, 'secret': secret});
    _handleAuth(res);
  }

  /// 登录已有账号。
  Future<void> login(String username, String secret) async {
    final res = await _post('/login', {'username': username, 'secret': secret});
    _handleAuth(res);
  }

  void _handleAuth(http.Response res) {
    if (res.statusCode != 200) {
      throw SyncException('认证失败（HTTP ${res.statusCode}）：${_errOf(res)}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _token = body['token'] as String?;
    _accountId = body['accountId'] as String?;
    if (_token == null) throw SyncException('服务器未返回 token');
  }

  /// 登记/配对设备。
  Future<void> registerDevice({String name = 'device'}) async {
    final res = await _post(
      '/device',
      {'deviceId': _deviceId, 'name': name},
      auth: true,
    );
    if (res.statusCode == 401) {
      throw SyncAuthException('登录状态已失效（服务端可能重启过），需要重新登录。');
    }
    if (res.statusCode != 200) {
      throw SyncException('设备登记失败（HTTP ${res.statusCode}）：${_errOf(res)}');
    }
  }

  /// 执行一次同步：推送本地自 [sinceCursor] 后的改动，拉取服务端新变更。
  /// 返回服务端最新游标（下次同步的起点）。
  Future<SyncResult> sync({required int sinceCursor}) async {
    final changes = await _collectLocalChanges(sinceCursor);
    final res = await _post(
      '/sync',
      {
        'deviceId': _deviceId,
        'changes': changes,
        'sinceCursor': sinceCursor,
      },
      auth: true,
    );
    if (res.statusCode == 401) {
      throw SyncAuthException('登录状态已失效（服务端可能重启过），需要重新登录。');
    }
    if (res.statusCode != 200) {
      throw SyncException('同步失败（HTTP ${res.statusCode}）：${_errOf(res)}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final changed = ((body['changed'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final cursor = (body['cursor'] as int?) ?? sinceCursor;
    final applied = await _applyRemote(changed);
    return SyncResult(cursor: cursor, pushed: changes.length, applied: applied);
  }

  /// 收集本地 version > sinceCursor 的记录，打包成服务端协议格式。
  Future<List<Map<String, dynamic>>> _collectLocalChanges(int sinceCursor) async {
    final out = <Map<String, dynamic>>[];
    final db = repo.db;

    final deckRows = await (db.select(db.decks)..where((t) => t.version.isBiggerThanValue(sinceCursor))).get();
    for (final d in deckRows) {
      out.add({
        'id': 'deck:${d.id}',
        'type': 'deck',
        'version': d.version,
        'deleted': d.deleted,
        'payload': {'name': d.name, 'parentId': d.parentId},
      });
    }

    final noteRows = await (db.select(db.notes)..where((t) => t.version.isBiggerThanValue(sinceCursor))).get();
    for (final n in noteRows) {
      out.add({
        'id': 'note:${n.id}',
        'type': 'note',
        'version': n.version,
        'deleted': n.deleted,
        'payload': {'noteTypeId': n.noteTypeId, 'fields': n.fields, 'tags': n.tags, 'guid': n.guid},
      });
    }

    final cardRows = await (db.select(db.cards)..where((t) => t.version.isBiggerThanValue(sinceCursor))).get();
    for (final c in cardRows) {
      out.add({
        'id': 'card:${c.id}',
        'type': 'card',
        'version': c.version,
        'deleted': c.deleted,
        'payload': {
          'noteId': c.noteId, 'deckId': c.deckId, 'templateIndex': c.templateIndex,
          'queue': c.queue, 'due': c.due, 'stability': c.stability,
          'difficulty': c.difficulty, 'stabilityFast': c.stabilityFast,
          'reps': c.reps, 'lapses': c.lapses, 'lastReview': c.lastReview,
        },
      });
    }
    return out;
  }

  /// 应用服务端变更到本地（LWW：仅当服务端 version 更高才覆盖）。
  Future<int> _applyRemote(List<Map<String, dynamic>> changed) async {
    final db = repo.db;
    var applied = 0;
    for (final rec in changed) {
      final id = (rec['id'] as String?) ?? '';
      final type = rec['type'] as String?;
      final version = (rec['version'] as int?) ?? 0;
      final deleted = (rec['deleted'] as bool?) ?? false;
      final payload = (rec['payload'] as Map<String, dynamic>?) ?? const {};
      final localId = id.contains(':') ? id.substring(id.indexOf(':') + 1) : id;

      try {
        switch (type) {
          case 'deck':
            final existing = await (db.select(db.decks)..where((t) => t.id.equals(localId))).getSingleOrNull();
            if (existing != null && existing.version >= version) break;
            if (existing == null) {
              await db.into(db.decks).insert(DecksCompanion.insert(
                    id: localId,
                    name: (payload['name'] as String?) ?? '',
                    parentId: Value(payload['parentId'] as String?),
                    deleted: Value(deleted),
                    version: version,
                  ));
            } else {
              await (db.update(db.decks)..where((t) => t.id.equals(localId))).write(DecksCompanion(
                    name: Value((payload['name'] as String?) ?? existing.name),
                    // parentId 必须一起回写，否则"在设备上把分组移到另一个父下"
                    // 这件事同步过去就丢了（insert 分支本来就带，update 分支漏了）。
                    // 注意用 containsKey 判断：顶层分组的 parentId 是合法的 null。
                    parentId: Value(payload.containsKey('parentId')
                        ? payload['parentId'] as String?
                        : existing.parentId),
                    deleted: Value(deleted),
                    version: Value(version),
                  ));
            }
            applied++;
            break;
          case 'note':
            final existing = await (db.select(db.notes)..where((t) => t.id.equals(localId))).getSingleOrNull();
            if (existing != null && existing.version >= version) break;
            if (existing == null) {
              await db.into(db.notes).insert(NotesCompanion.insert(
                    id: localId,
                    noteTypeId: (payload['noteTypeId'] as String?) ?? '',
                    fields: (payload['fields'] as String?) ?? '[]',
                    tags: Value((payload['tags'] as String?) ?? ''),
                    guid: (payload['guid'] as String?) ?? localId,
                    deleted: Value(deleted),
                    version: version,
                  ));
            } else {
              await (db.update(db.notes)..where((t) => t.id.equals(localId))).write(NotesCompanion(
                    fields: Value((payload['fields'] as String?) ?? existing.fields),
                    tags: Value((payload['tags'] as String?) ?? existing.tags),
                    deleted: Value(deleted),
                    version: Value(version),
                  ));
            }
            applied++;
            break;
          case 'card':
            final existing = await (db.select(db.cards)..where((t) => t.id.equals(localId))).getSingleOrNull();
            if (existing != null && existing.version >= version) break;
            if (existing == null) {
              await db.into(db.cards).insert(CardsCompanion.insert(
                    id: localId,
                    noteId: (payload['noteId'] as String?) ?? '',
                    deckId: (payload['deckId'] as String?) ?? '',
                    templateIndex: Value((payload['templateIndex'] as int?) ?? 0),
                    queue: Value((payload['queue'] as int?) ?? 0),
                    due: Value((payload['due'] as int?) ?? 0),
                    stability: Value((payload['stability'] as num?)?.toDouble() ?? 0),
                    difficulty: Value((payload['difficulty'] as num?)?.toDouble() ?? 0),
                    stabilityFast: Value((payload['stabilityFast'] as num?)?.toDouble() ?? 0),
                    reps: Value((payload['reps'] as int?) ?? 0),
                    lapses: Value((payload['lapses'] as int?) ?? 0),
                    lastReview: Value((payload['lastReview'] as int?) ?? 0),
                    deleted: Value(deleted),
                    version: version,
                  ));
            } else {
              await (db.update(db.cards)..where((t) => t.id.equals(localId))).write(CardsCompanion(
                    queue: Value((payload['queue'] as int?) ?? existing.queue),
                    due: Value((payload['due'] as int?) ?? existing.due),
                    stability: Value((payload['stability'] as num?)?.toDouble() ?? existing.stability),
                    difficulty: Value((payload['difficulty'] as num?)?.toDouble() ?? existing.difficulty),
                    reps: Value((payload['reps'] as int?) ?? existing.reps),
                    lapses: Value((payload['lapses'] as int?) ?? existing.lapses),
                    lastReview: Value((payload['lastReview'] as int?) ?? existing.lastReview),
                    deleted: Value(deleted),
                    version: Value(version),
                  ));
            }
            applied++;
            break;
        }
      } catch (_) {
        // 单条失败不阻断整体同步。
      }
    }
    return applied;
  }

  String _errOf(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      return (b['error'] as String?) ?? res.body;
    } catch (_) {
      return res.body;
    }
  }

  /// 注销（仅本地清理 token）。
  void logout() {
    _token = null;
    _accountId = null;
  }
}

/// 认证成功后应当使用的游标。
///
/// 游标的含义是"这个**账号**在这个服务端上同步到了哪个 version"，所以它只在
/// 账号不变时才有延续意义。换账号（典型场景：服务端重启把库清了 —— 早期版本
/// 还是纯内存，重启即清空；用户于是只能重新注册，拿到一个全新的 accountId）
/// 之后继续用旧游标会形成一个无声死局：
///   `_collectLocalChanges` 只挑 `version > sinceCursor` 的本地记录，而本地
///   记录的 version 全都小于旧账号推进出来的游标 → 推送 0 条；
///   服务端 `pull` 又只返回新账号名下的记录 → 拉到 0 条；
///   界面显示"同步完成：推送 0 条，应用 0 条"，看起来一切正常，实际永远同步不动。
/// 因此账号一变，游标必须归零，让本地数据整份重推一次。
///
/// 纯函数，便于单测；调用点见 sync_screen.dart 的 `_adoptSession`。
int nextCursorAfterAuth({
  required String? previousAccountId,
  required String? accountId,
  required int currentCursor,
}) {
  // 没拿到账号 id（认证失败等）时绝不清零：一次失败的登录不该毁掉同步进度。
  if (accountId == null || accountId.isEmpty) return currentCursor;
  // 首次绑定账号：本来就没有进度，归零无害（此时 currentCursor 通常已是 0）。
  if (previousAccountId == null || previousAccountId.isEmpty) return 0;
  // 同一个账号：增量游标继续有效。
  if (previousAccountId == accountId) return currentCursor;
  // 换账号：旧游标对新账号没有任何意义。
  return 0;
}

/// 一次同步的结果。
class SyncResult {
  const SyncResult({required this.cursor, required this.pushed, required this.applied});
  final int cursor;
  final int pushed;
  final int applied;
}

/// 同步异常（带用户可读信息）。
class SyncException implements Exception {
  SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 会话失效（HTTP 401）：与"网络不通""密码错误"区分开，
/// 上层据此自动用已存账号重登一次并重试，用户无需手动点登录。
class SyncAuthException extends SyncException {
  SyncAuthException(super.message);
}
