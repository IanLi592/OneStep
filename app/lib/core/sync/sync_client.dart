import 'dart:convert';

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
  SyncClient(this.repo, {required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final CollectionRepo repo;
  final String baseUrl;
  final http.Client _client;

  String? _token;
  String? _accountId;
  String _deviceId = 'unknown';

  bool get isAuthed => _token != null;

  /// 设置本机设备 id（持久化后由调用方注入）。
  void setDeviceId(String id) => _deviceId = id;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// 注册新账号。
  Future<void> register(String username, String secret) async {
    final res = await _client.post(
      _u('/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'secret': secret}),
    );
    _handleAuth(res);
  }

  /// 登录已有账号。
  Future<void> login(String username, String secret) async {
    final res = await _client.post(
      _u('/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'secret': secret}),
    );
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
    final res = await _client.post(
      _u('/device'),
      headers: _authHeaders,
      body: jsonEncode({'deviceId': _deviceId, 'name': name}),
    );
    if (res.statusCode != 200) {
      throw SyncException('设备登记失败（HTTP ${res.statusCode}）：${_errOf(res)}');
    }
  }

  /// 执行一次同步：推送本地自 [sinceCursor] 后的改动，拉取服务端新变更。
  /// 返回服务端最新游标（下次同步的起点）。
  Future<SyncResult> sync({required int sinceCursor}) async {
    final changes = await _collectLocalChanges(sinceCursor);
    final res = await _client.post(
      _u('/sync'),
      headers: _authHeaders,
      body: jsonEncode({
        'deviceId': _deviceId,
        'changes': changes,
        'sinceCursor': sinceCursor,
      }),
    );
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

  String? get accountId => _accountId;
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
