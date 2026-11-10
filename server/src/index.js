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
import { mkdirSync } from 'node:fs';
import { dirname, isAbsolute, resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { SyncStore, SyncError } from './store.js';
import { startupBanner } from './addresses.js';

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

// 默认数据文件：<server 目录>/data/sync.json（.gitignore 已忽略 server/data/）。
const DEFAULT_SYNC_DB = fileURLToPath(new URL('../data/sync.json', import.meta.url));

/**
 * 解析同步数据文件路径（纯函数，便于单测）。
 *
 * 规则：
 *   - 没设 ONESTEP_SYNC_DB       -> 用 defaultPath（默认 server/data/sync.json）。
 *   - 设了相对路径               -> 按当前工作目录解析成绝对路径。
 *   - 设了 ':memory:' 或 'none'  -> 返回 null，即刻意不落盘（只给测试/临时演示用）。
 *
 * 为什么要有默认值（2026-11-03 的真实事故）：原来这里是
 * `process.env.ONESTEP_SYNC_DB || null`，而 store.js 的 save() 在 filePath 为
 * null 时第一行就 return。于是照 README 的裸命令 `node src/index.js` 启动时，
 * 全部账号与同步记录**只活在内存里**：进程一重启就静默清空，不报错也不提示。
 * 用户看到的现象是"手机登不上电脑上注册的账号，只能重新注册"，而重新注册拿到
 * 的是一个全新的空账号，"立即同步"自然一条卡片也拉不到——当时服务端里躺着
 * 990 条记录，全在这次重启里没了。
 *
 * @param {Record<string,string|undefined>} env
 * @param {string} defaultPath
 * @returns {string|null} 绝对路径，或 null 表示不持久化
 */
export function resolveSyncDbPath(env = process.env, defaultPath = DEFAULT_SYNC_DB) {
  const raw = (env.ONESTEP_SYNC_DB ?? '').trim();
  if (raw === '') return defaultPath;
  if (raw === ':memory:' || raw.toLowerCase() === 'none') return null;
  return isAbsolute(raw) ? raw : resolve(process.cwd(), raw);
}

// 直接运行时启动（跨平台比较，避免 Windows 反斜杠/盘符导致判断失败）。
const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  const port = process.env.PORT ? Number(process.env.PORT) : 8787;
  const filePath = resolveSyncDbPath();
  // 目录不存在就先建好：否则 store.save() 会在第一次注册/同步时抛 ENOENT，
  // 被 catch 成 400 返回给客户端，看起来像"客户端请求有问题"。
  if (filePath) mkdirSync(dirname(filePath), { recursive: true });
  const { server } = createApp({ filePath });
  // 横幅在 listen 成功后才打：否则端口被占时先打印了"已启动 + 该填的地址"，
  // 反而把人误导到别的地方去查。
  server.listen(port, () => {
    for (const line of startupBanner({ port, dataFile: filePath })) {
      console.log(line);
    }
  });
}
