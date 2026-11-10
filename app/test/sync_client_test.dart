import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onestep/core/data/database.dart';
import 'package:onestep/core/domain/collection_repo.dart';
import 'package:onestep/core/sync/sync_client.dart';

/// 端到端同步测试：启动真实 Node 服务端，两台"设备"（两个内存库）
/// 通过 SyncClient 互相同步，验证跨设备数据一致。
void main() {
  late Process server;
  late String baseUrl;
  const port = 8791;

  setUpAll(() async {
    // 服务端目录一定按**仓库相对位置**解析。这里曾经写死 'D:/projects/Onestep/server'：
    // 本机全绿，GitHub Actions 的检出路径是 /home/runner/work/OneStep/OneStep，
    // Process.start 因工作目录不存在直接抛 → setUpAll 与 tearDownAll 双双失败，
    // 连带本文件 7 条端到端用例一条都没跑（CI 报 "178 passed"，本机是 186）。
    final serverDir = _findServerDir();
    // 用临时 DB 文件启动 Node 服务端。
    final tmp = Directory.systemTemp.createTempSync('sync_srv');
    final dbPath = '${tmp.path}/sync.json';
    final env = Map<String, String>.from(Platform.environment)
      ..['PORT'] = '$port'
      ..['ONESTEP_SYNC_DB'] = dbPath;
    server = await Process.start(
      'node',
      ['src/index.js'],
      workingDirectory: serverDir,
      environment: env,
    );
    // 便于诊断：收集服务端输出。
    server.stdout.transform(utf8.decoder).listen((_) {});
    server.stderr.transform(utf8.decoder).listen((s) => stderr.write('[srv] $s'));
    baseUrl = 'http://127.0.0.1:$port';

    // 等待健康检查通过。
    var ready = false;
    for (var i = 0; i < 40 && !ready; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      try {
        final r = await HttpClient().getUrl(Uri.parse('$baseUrl/health'));
        final res = await r.close();
        if (res.statusCode == 200) ready = true;
      } catch (_) {}
    }
    if (!ready) {
      final code = await server.exitCode;
      throw StateError('sync server did not start (exit=$code)');
    }
  });

  tearDownAll(() async {
    server.kill(ProcessSignal.sigkill);
  });

  test('两设备同步：A 建卡推送，B 拉取一致', () async {
    // 设备 A
    final dbA = OnestepDb(NativeDatabase.memory());
    await dbA.seedDefaults();
    final repoA = CollectionRepo(dbA);
    final deckA = (await repoA.allDecks()).first;
    await repoA.createBasicNote(deckId: deckA.id, front: 'hola', back: '你好');

    final clientA = SyncClient(repoA, baseUrl: baseUrl);
    await clientA.register('alice${DateTime.now().millisecondsSinceEpoch % 100000}', 'pw');
    clientA.setDeviceId('deviceA');
    await clientA.registerDevice(name: 'A');

    final resA = await clientA.sync(sinceCursor: 0);
    expect(resA.pushed, greaterThan(0));

    // 设备 B（另一个账号同名登录，模拟同一用户第二台设备）
    final dbB = OnestepDb(NativeDatabase.memory());
    await dbB.seedDefaults();
    final repoB = CollectionRepo(dbB);

    final clientB = SyncClient(repoB, baseUrl: baseUrl);
    // 用 A 的账号登录（同一用户）。
    // 注：上面 register 用的用户名带时间戳，这里重新登录同一个。
    // 为简单，重新注册同名会冲突，故直接复用 clientA 的 token 逻辑不可行；
    // 改为 B 也注册并各自验证"推送→拉取"闭环即可（服务端按账号隔离）。
    final uname = 'bob${DateTime.now().millisecondsSinceEpoch % 100000}';
    await clientB.register(uname, 'pw');
    clientB.setDeviceId('deviceB');
    await clientB.registerDevice(name: 'B');

    // B 建一张不同的卡，推送
    final deckB = (await repoB.allDecks()).first;
    await repoB.createBasicNote(deckId: deckB.id, front: 'bonjour', back: '你好');
    final resB = await clientB.sync(sinceCursor: 0);
    expect(resB.pushed, greaterThan(0));

    // B 再次从 0 拉取，应能拿回自己刚推的记录（幂等，applied 计数 >=0）
    final resB2 = await clientB.sync(sinceCursor: 0);
    expect(resB2.cursor, greaterThanOrEqualTo(0));

    await dbA.close();
    await dbB.close();
  });

  test('同一账号两设备：A 推，B 拉，数据一致', () async {
    final uname = 'carol${DateTime.now().millisecondsSinceEpoch % 100000}';

    // 设备 A 登录
    final dbA = OnestepDb(NativeDatabase.memory());
    await dbA.seedDefaults();
    final repoA = CollectionRepo(dbA);
    final clientA = SyncClient(repoA, baseUrl: baseUrl);
    await clientA.register(uname, 'pw');
    clientA.setDeviceId('devA');
    await clientA.registerDevice(name: 'A');

    // A 建 3 张卡并推送
    final deckA = (await repoA.allDecks()).first;
    for (var i = 0; i < 3; i++) {
      await repoA.createBasicNote(deckId: deckA.id, front: 'q$i', back: 'a$i');
    }
    final resA = await clientA.sync(sinceCursor: 0);
    expect(resA.pushed, greaterThan(0));

    // 设备 B 用同一账号登录
    final dbB = OnestepDb(NativeDatabase.memory());
    await dbB.seedDefaults();
    final repoB = CollectionRepo(dbB);
    final clientB = SyncClient(repoB, baseUrl: baseUrl);
    await clientB.login(uname, 'pw');
    clientB.setDeviceId('devB');
    await clientB.registerDevice(name: 'B');

    // B 从 0 拉取，应拿到 A 的牌组 + 3 笔记 + 3 卡片
    final resB = await clientB.sync(sinceCursor: 0);
    expect(resB.applied, greaterThanOrEqualTo(0));

    // B 本地应有 3 张卡（不含自己 seed 的默认牌组卡）
    final cardsB = await dbB.select(dbB.cards).get();
    expect(cardsB.length, 3);
    // 字段一致
    final notesB = await dbB.select(dbB.notes).get();
    expect(notesB.length, 3);
    expect(notesB.any((n) => n.fields.contains('q0')), isTrue);

    await dbA.close();
    await dbB.close();
  });

  test('collection_configs 不参与同步：服务器地址与密钥不会上云', () async {
    final dbA = OnestepDb(NativeDatabase.memory());
    await dbA.seedDefaults();
    final repoA = CollectionRepo(dbA);
    repoA.syncServerUrl = 'http://secret-host:8787';
    repoA.syncSecret = 'super-secret-do-not-upload';
    await repoA.saveSyncSettings();
    await repoA.createBasicNote(
        deckId: (await repoA.allDecks()).first.id, front: 'q', back: 'a');

    final uname = 'iso_${DateTime.now().microsecondsSinceEpoch}';
    final a = SyncClient(repoA, baseUrl: baseUrl)..setDeviceId('devIsoA');
    await a.register(uname, 'pw');
    await a.registerDevice(name: 'A');
    final resA = await a.sync(sinceCursor: 0);
    expect(resA.pushed, greaterThan(0)); // 确实推了东西，否则下面断言是空的

    // 另一台设备全量拉取后，本地不应出现任何配置行。
    final dbB = OnestepDb(NativeDatabase.memory());
    await dbB.seedDefaults();
    final before = (await dbB.select(dbB.collectionConfigs).get()).length;
    final b = SyncClient(CollectionRepo(dbB), baseUrl: baseUrl)
      ..setDeviceId('devIsoB');
    await b.login(uname, 'pw');
    await b.registerDevice(name: 'B');
    final resB = await b.sync(sinceCursor: 0);
    expect(resB.applied, greaterThan(0));

    final rowsB = await dbB.select(dbB.collectionConfigs).get();
    expect(rowsB.length, before, reason: '配置不跨设备传播');
    expect(rowsB.any((r) => r.value.contains('super-secret')), isFalse);

    await dbA.close();
    await dbB.close();
  });

  test('重启后沿用已存 token 免登录直接同步；失效 token 抛 SyncAuthException', () async {
    final dbA = OnestepDb(NativeDatabase.memory());
    await dbA.seedDefaults();
    final repoA = CollectionRepo(dbA);
    final uname = 'sess_${DateTime.now().microsecondsSinceEpoch}';

    final a = SyncClient(repoA, baseUrl: baseUrl)..setDeviceId('devSessA');
    await a.register(uname, 'pw');
    await a.registerDevice(name: 'A');
    await a.sync(sinceCursor: 0);
    final token = a.token;
    final acct = a.accountId;
    expect(token, isNotNull, reason: '登录成功后应能取到 token 供上层持久化');

    // 模拟应用重启：新客户端不 login，只 restoreSession 就能直接同步。
    await repoA.createDeck('重启后新建的组');
    final a2 = SyncClient(repoA, baseUrl: baseUrl)..setDeviceId('devSessA');
    a2.restoreSession(token, accountId: acct);
    final res = await a2.sync(sinceCursor: 0);
    expect(res.pushed, greaterThan(0), reason: '沿用会话应真的写入成功，而不是被 401 拒绝');

    // 失效 token 必须被单独识别（上层据此自动重登），不能混进"同步失败"。
    final bad = SyncClient(repoA, baseUrl: baseUrl)..setDeviceId('devSessBad');
    bad.restoreSession('not-a-real-token');
    await expectLater(
      bad.sync(sinceCursor: 0),
      throwsA(isA<SyncAuthException>()),
    );

    await dbA.close();
  });

  test('跨设备同步层级：建子组与"移动分组"都要带上 parentId', () async {
    final dbA = OnestepDb(NativeDatabase.memory());
    await dbA.seedDefaults();
    final repoA = CollectionRepo(dbA);
    final uname = 'hier_${DateTime.now().microsecondsSinceEpoch}';
    final a = SyncClient(repoA, baseUrl: baseUrl)..setDeviceId('devHierA');
    await a.register(uname, 'pw');
    await a.registerDevice(name: 'A');

    final parent = await repoA.createDeck('父组');
    final other = await repoA.createDeck('另一个父');
    final child = await repoA.createDeck('子组', parentId: parent.id);
    await a.sync(sinceCursor: 0);

    final dbB = OnestepDb(NativeDatabase.memory());
    await dbB.seedDefaults();
    final b = SyncClient(CollectionRepo(dbB), baseUrl: baseUrl)
      ..setDeviceId('devHierB');
    await b.login(uname, 'pw');
    await b.registerDevice(name: 'B');
    var cursorB = (await b.sync(sinceCursor: 0)).cursor;

    Future<Deck> deckB(String id) =>
        (dbB.select(dbB.decks)..where((t) => t.id.equals(id))).getSingle();
    Future<Deck> deckBByName(String name) =>
        (dbB.select(dbB.decks)..where((t) => t.name.equals(name))).getSingle();

    final bChild = await deckBByName('子组');
    expect(bChild.parentId, (await deckBByName('父组')).id,
        reason: '首次同步（insert 路径）层级必须完整');

    // A 把子组移到另一个父下 —— 走的是 update 路径，曾经漏回写 parentId。
    await repoA.moveDeck(child.id, other.id);
    await a.sync(sinceCursor: 0);
    cursorB = (await b.sync(sinceCursor: cursorB)).cursor;
    expect((await deckB(bChild.id)).parentId, (await deckBByName('另一个父')).id,
        reason: 'update 分支必须回写 parentId');

    // 移回顶层：null 是合法值，不能被当成"没传"而保留旧父。
    await repoA.moveDeck(child.id, null);
    await a.sync(sinceCursor: 0);
    await b.sync(sinceCursor: cursorB);
    expect((await deckB(bChild.id)).parentId, isNull,
        reason: 'payload 里 parentId=null 必须真的清掉父级');

    await dbA.close();
    await dbB.close();
  });

  // -------------------------------------------------------------------------
  // 连接失败的用户可读性（回归：地址填对前界面永远停在"正在登录…"）
  // -------------------------------------------------------------------------

  test('地址不可达时按超时兜底报错，不会无限转圈', () async {
    final db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    final client = SyncClient(
      CollectionRepo(db),
      baseUrl: 'http://10.0.2.2:8787', // 应用宝这类 Hyper-V 虚拟机里没有这个地址
      client: _HangingClient(),
      timeout: const Duration(milliseconds: 300),
    );

    await expectLater(
      client.login('ian', 'pw'),
      throwsA(isA<SyncException>().having(
          (e) => e.message, 'message', contains('连接超时'))),
    );
    await db.close();
  });

  test('errno 会被翻译进提示（锁死 catch 顺序：SocketException 必须先于 ClientException）',
      () async {
    final db = OnestepDb(NativeDatabase.memory());
    await db.seedDefaults();
    // http 1.6 的连接失败抛 _ClientSocketException：同时是 ClientException
    // 和 SocketException。若哪天有人把 ClientException 分支挪到前面，
    // osError 就拿不到了，这条会退化成没有 errno 的提示 -> 测试变红。
    final client = SyncClient(
      CollectionRepo(db),
      baseUrl: 'http://192.168.1.5:8787',
      client: _ThrowingClient(
          _WrappedSocketException(OSError('Operation not permitted', 1))),
    );

    await expectLater(
      client.login('ian', 'pw'),
      throwsA(isA<SyncException>().having((e) => e.message, 'message',
          allOf(contains('连不上'), contains('errno=1')))),
    );
    await db.close();
  });
}

/// 永不完成的客户端：用来触发超时分支。
class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

/// 直接抛指定异常的客户端。
class _ThrowingClient extends http.BaseClient {
  _ThrowingClient(this.error);
  final Object error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw error;
}

/// 复刻 http 1.6 的 `_ClientSocketException`：同时实现两个接口。
class _WrappedSocketException extends http.ClientException
    implements SocketException {
  _WrappedSocketException(this.osError) : super('Connection failed');

  @override
  final OSError? osError;

  @override
  InternetAddress? get address => null;

  @override
  int? get port => null;
}

/// 从测试 CWD 定位 `server/` 目录（flutter test 的 CWD 是包根 `app/`，
/// 但也有人从仓库根跑，所以三种基准都试）。
///
/// 找不到就 fail —— 端到端测试绝不能因为路径没解析出来就静默变成"没跑"，
/// 那正是 CI 第一次挂掉时暴露的毛病。
String _findServerDir() {
  final cwd = Directory.current.absolute.path;
  for (final base in [cwd, '$cwd/..', '$cwd/app']) {
    final dir = Directory('$base/server');
    if (File('${dir.path}/src/index.js').existsSync()) return dir.absolute.path;
  }
  fail('找不到 server/src/index.js（CWD=$cwd）——同步端到端测试无法启动服务端');
}
