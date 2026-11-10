// 持久化与"重启后还能登录/同步"的回归守卫。
//
// 真实事故（2026-11-03）：src/index.js 原来是 `process.env.ONESTEP_SYNC_DB || null`，
// 而 store.js 的 save() 在 filePath 为 null 时第一行就 return。照 README 的裸命令
// `node src/index.js` 启动时，账号与同步记录只存在内存里，进程一重启就静默清空：
// 手机表现为"登不上电脑上注册的账号，只能重新注册"，注册后又拿到全新空账号，
// 于是"立即同步"什么也拉不到。当时被清掉的是 990 条记录。

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, isAbsolute } from 'node:path';
import { createApp, resolveSyncDbPath } from '../src/index.js';
import { SyncStore } from '../src/store.js';

const tmpDir = () => mkdtempSync(join(tmpdir(), 'onestep-persist-'));

async function postJson(url, body, token) {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

const listen = (server) =>
  new Promise((resolve) => server.listen(0, () => resolve(`http://127.0.0.1:${server.address().port}`)));
const close = (server) => new Promise((resolve) => server.close(resolve));

// ---- 路径解析（bug 的直接来源）----

test('没设 ONESTEP_SYNC_DB 时默认落盘，而不是纯内存', () => {
  assert.equal(resolveSyncDbPath({}, 'D:/srv/data/sync.json'), 'D:/srv/data/sync.json');
  // 空串/纯空格等同于没设，也必须走默认值（旧写法 `|| null` 会掉进纯内存）。
  assert.equal(resolveSyncDbPath({ ONESTEP_SYNC_DB: '' }, 'D:/srv/data/sync.json'), 'D:/srv/data/sync.json');
  assert.equal(resolveSyncDbPath({ ONESTEP_SYNC_DB: '   ' }, 'D:/srv/data/sync.json'), 'D:/srv/data/sync.json');
});

test('真实默认值指向 server/data/sync.json 且是绝对路径', () => {
  const p = resolveSyncDbPath({});
  assert.ok(p && isAbsolute(p), `应为绝对路径，实际 ${p}`);
  assert.ok(p.replaceAll('\\', '/').endsWith('server/data/sync.json'), `默认路径不对：${p}`);
});

test('显式相对路径按当前工作目录解析成绝对路径', () => {
  const p = resolveSyncDbPath({ ONESTEP_SYNC_DB: join('data', 'rel.json') });
  assert.equal(p, join(process.cwd(), 'data', 'rel.json'));
});

test('只有 :memory: / none 才允许不落盘（测试与临时演示的逃生门）', () => {
  assert.equal(resolveSyncDbPath({ ONESTEP_SYNC_DB: ':memory:' }, 'D:/srv/data/sync.json'), null);
  assert.equal(resolveSyncDbPath({ ONESTEP_SYNC_DB: 'NONE' }, 'D:/srv/data/sync.json'), null);
});

// ---- 重启往返（端到端，走真实 HTTP）----

test('服务端重启后：同一账号仍能登录，并拉到重启前的记录', async () => {
  const file = join(tmpDir(), 'sync.json');

  const app1 = createApp({ filePath: file });
  const base1 = await listen(app1.server);
  const reg = await postJson(`${base1}/register`, { username: 'ian', secret: 'pw' });
  assert.equal(reg.status, 200);
  const sync1 = await postJson(
    `${base1}/sync`,
    { deviceId: 'devA', changes: [{ id: 'card:1', type: 'card', version: 100, deleted: false, payload: { x: 1 } }] },
    reg.body.token,
  );
  assert.equal(sync1.status, 200);
  await close(app1.server);

  // 模拟进程重启：全新实例读同一个文件。
  const app2 = createApp({ filePath: file });
  const base2 = await listen(app2.server);
  const login = await postJson(`${base2}/login`, { username: 'ian', secret: 'pw' });
  assert.equal(login.status, 200, '重启后登录必须成功（旧行为是 401「账号或密钥错误」）');
  assert.equal(login.body.accountId, reg.body.accountId, 'accountId 必须还是同一个，否则客户端游标就失效了');

  const pulled = await postJson(`${base2}/sync`, { deviceId: 'devA', changes: [], sinceCursor: 0 }, login.body.token);
  assert.equal(pulled.status, 200);
  assert.equal(pulled.body.changed.length, 1, '重启前推的记录必须还在');
  assert.equal(pulled.body.changed[0].id, 'card:1');
  await close(app2.server);
});

// ---- 写盘健壮性 ----

test('save() 先写 .tmp 再原子改名，且能覆盖已存在的目标文件', () => {
  const file = join(tmpDir(), 'sync.json');
  const s = new SyncStore({ filePath: file });
  s.createAccount({ username: 'a', secret: 'b' });
  s.save();
  s.save(); // 第二次 rename 的目标已存在：Windows 上必须也能替换成功
  assert.ok(existsSync(file));
  assert.ok(!existsSync(`${file}.tmp`), '不应残留 .tmp');
  const back = new SyncStore({ filePath: file });
  assert.equal(back.accounts.size, 1);
});

test('数据文件损坏时改名留证，绝不静默用空库覆盖原件', () => {
  const dir = tmpDir();
  const file = join(dir, 'sync.json');
  const broken = '{"accounts": 这不是JSON';
  writeFileSync(file, broken, 'utf8');

  const s = new SyncStore({ filePath: file }); // _load 解析失败
  const kept = readdirSync(dir).filter((f) => f.includes('.corrupt-'));
  assert.equal(kept.length, 1, '坏文件应被改名保留');
  assert.equal(readFileSync(join(dir, kept[0]), 'utf8'), broken, '原件内容必须一字不改地留着');
  assert.equal(s.accounts.size, 0, '本次仍从空库开始，但原件已保住');
});
