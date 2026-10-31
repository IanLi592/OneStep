// 同步服务端 HTTP API（纯 Node，无外部依赖）。
//
// 端点：
//   POST /register         { username, secret }            -> 创建账号，返回 token
//   POST /login            { username, secret }            -> 返回 token
//   POST /device           (Bearer) { deviceId, name }      -> 配对/登记设备
//   POST /sync             (Bearer) { deviceId, changes[] } -> 推送变更并拉取，返回 { changed, cursor }
//
// 认证：账号级 bearer token（MVP 用不透明 token，生产应签名+过期）。

import { createServer } from 'node:http';
import { randomBytes } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { SyncStore, SyncError } from './store.js';

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 20 * 1024 * 1024) reject(new Error('body too large'));
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch {
        reject(new Error('invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(body);
}

function bearer(req) {
  const h = req.headers['authorization'] || '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1] : null;
}

export function createApp({ filePath = null } = {}) {
  const store = new SyncStore({ filePath });
  /** @type {Map<string, string>} token -> accountId */
  const tokens = new Map();

  function accountIdFor(req) {
    const t = bearer(req);
    return t ? tokens.get(t) || null : null;
  }

  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      const path = url.pathname;

      if (req.method === 'POST' && path === '/register') {
        const { username, secret } = await readBody(req);
        if (!username || !secret) return send(res, 400, { error: '缺少 username/secret' });
        const account = store.createAccount({ username, secret });
        const token = randomBytes(24).toString('hex');
        tokens.set(token, account.id);
        store.save();
        return send(res, 200, { token, accountId: account.id, username: account.username });
      }

      if (req.method === 'POST' && path === '/login') {
        const { username, secret } = await readBody(req);
        const account = store.authAccount(username, secret);
        const token = randomBytes(24).toString('hex');
        tokens.set(token, account.id);
        return send(res, 200, { token, accountId: account.id, username: account.username });
      }

      if (req.method === 'POST' && path === '/device') {
        const accountId = accountIdFor(req);
        if (!accountId) return send(res, 401, { error: '未认证' });
        const { deviceId, name } = await readBody(req);
        if (!deviceId) return send(res, 400, { error: '缺少 deviceId' });
        const device = store.registerDevice({ accountId, deviceId, name });
        return send(res, 200, { device });
      }

      if (req.method === 'POST' && path === '/sync') {
        const accountId = accountIdFor(req);
        if (!accountId) return send(res, 401, { error: '未认证' });
        const { deviceId, changes = [], sinceCursor = 0 } = await readBody(req);
        if (deviceId) store.registerDevice({ accountId, deviceId });
        const pushResults = store.push(accountId, changes);
        const { changed, cursor } = store.pull(accountId, sinceCursor);
        store.save();
        return send(res, 200, { push: pushResults, changed, cursor });
      }

      if (req.method === 'GET' && path === '/health') {
        return send(res, 200, { ok: true });
      }

      return send(res, 404, { error: 'not found' });
    } catch (e) {
      if (e instanceof SyncError) {
        const code = e.code === 'unauthorized' ? 401 : e.code === 'conflict' ? 409 : 400;
        return send(res, code, { error: e.message });
      }
      return send(res, 400, { error: e.message || 'bad request' });
    }
  });

  return { server, store };
}

// 直接运行时启动（跨平台比较，避免 Windows 反斜杠/盘符导致判断失败）。
const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  const port = process.env.PORT ? Number(process.env.PORT) : 8787;
  const filePath = process.env.ONESTEP_SYNC_DB || null;
  const { server } = createApp({ filePath });
  server.listen(port, () => {
    console.log(`Onestep sync server on http://localhost:${port}`);
  });
}
