import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { SyncStore, SyncError } from '../src/store.js';

test('创建账号与鉴权', () => {
  const store = new SyncStore();
  const a = store.createAccount({ username: 'ian', secret: 'pw1' });
  assert.ok(a.id);
  assert.throws(() => store.createAccount({ username: 'ian', secret: 'x' }), SyncError);
  const ok = store.authAccount('ian', 'pw1');
  assert.equal(ok.id, a.id);
  assert.throws(() => store.authAccount('ian', 'wrong'), SyncError);
});

test('push/pull：新记录被拉取，游标推进', () => {
  const store = new SyncStore();
  const a = store.createAccount({ username: 'ian', secret: 'pw' });
  store.push(a.id, [
    { id: 'n1', type: 'note', version: 100, payload: { front: 'hola' } },
    { id: 'n2', type: 'note', version: 101, payload: { front: 'bonjour' } },
  ]);
  const { changed, cursor } = store.pull(a.id, 0);
  assert.equal(changed.length, 2);
  assert.equal(cursor, 101);
  // 游标之后无新变更
  const again = store.pull(a.id, cursor);
  assert.equal(again.changed.length, 0);
  assert.equal(again.cursor, cursor);
});

test('LWW：更高 version 覆盖，更低被拒并回传权威版本', () => {
  const store = new SyncStore();
  const a = store.createAccount({ username: 'ian', secret: 'pw' });
  store.push(a.id, [{ id: 'n1', type: 'note', version: 100, payload: { v: 1 } }]);
  // 更新版本覆盖
  const res2 = store.push(a.id, [{ id: 'n1', type: 'note', version: 200, payload: { v: 2 } }]);
  assert.equal(res2[0].record.payload.v, 2);
  // 陈旧版本被拒，回传服务端权威版本
  const res3 = store.push(a.id, [{ id: 'n1', type: 'note', version: 150, payload: { v: 99 } }]);
  assert.equal(res3[0].stale, true);
  assert.equal(res3[0].record.payload.v, 2);
});

test('删除记录作为 tombstone 同步', () => {
  const store = new SyncStore();
  const a = store.createAccount({ username: 'ian', secret: 'pw' });
  store.push(a.id, [{ id: 'n1', type: 'note', version: 100, payload: { v: 1 } }]);
  store.push(a.id, [{ id: 'n1', type: 'note', version: 300, deleted: true }]);
  const { changed } = store.pull(a.id, 0);
  const rec = changed.find((r) => r.id === 'n1');
  assert.equal(rec.deleted, true);
});

test('跨账号隔离：不能拉取或覆盖他人记录', () => {
  const store = new SyncStore();
  const a = store.createAccount({ username: 'a', secret: '1' });
  const b = store.createAccount({ username: 'b', secret: '2' });
  store.push(a.id, [{ id: 'a1', type: 'note', version: 10, payload: { secret: true } }]);
  // b 拉不到 a 的记录
  const pullB = store.pull(b.id, 0);
  assert.equal(pullB.changed.length, 0);
  // b 不能覆盖 a 的记录
  const pushB = store.push(b.id, [{ id: 'a1', type: 'note', version: 999, payload: { evil: true } }]);
  assert.equal(pushB[0].ok, false);
});

test('设备登记与绑定隔离', () => {
  const store = new SyncStore();
  const a = store.createAccount({ username: 'a', secret: '1' });
  const b = store.createAccount({ username: 'b', secret: '2' });
  const d = store.registerDevice({ accountId: a.id, deviceId: 'dev1', name: 'Pixel' });
  assert.equal(d.accountId, a.id);
  assert.throws(
    () => store.registerDevice({ accountId: b.id, deviceId: 'dev1', name: 'x' }),
    SyncError,
  );
});

test('文件持久化往返', () => {
  const dir = mkdtempSync(join(tmpdir(), 'onestep-'));
  const file = join(dir, 'db.json');
  const s1 = new SyncStore({ filePath: file });
  const a = s1.createAccount({ username: 'ian', secret: 'pw' });
  s1.push(a.id, [{ id: 'n1', type: 'note', version: 42, payload: { hi: 'there' } }]);
  s1.save();

  const s2 = new SyncStore({ filePath: file });
  const { changed } = s2.pull(a.id, 0);
  assert.equal(changed.length, 1);
  assert.equal(changed[0].payload.hi, 'there');
});
