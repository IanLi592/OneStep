// 同步存储层（MVP）：基于内存 + 可选 JSON 文件持久化。
//
// 模型（"哑终端云"，dumb-cloud sync）：
//  - Account：一个用户账号（用户名 + 同步密钥）。
//  - Device：账号下的设备，用于配对与追踪同步游标。
//  - Record：一条可同步记录（牌组/笔记/卡片/日志等），带 version（毫秒时间戳）
//            与 payload。合并策略为记录级"后写胜出"(LWW)。
//
// 该层不关心具体记录语义，只负责：按账号存记录、按 version 去重合并、
// 返回某游标之后的所有变更。真正的冲突副本保留在客户端本地。

import { readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs';

let nextIdCounter = 1;
function genId(prefix) {
  // 单进程 MVP 足够；生产应换成 UUID。
  return `${prefix}_${Date.now().toString(36)}_${(nextIdCounter++).toString(36)}`;
}

export class SyncStore {
  constructor({ filePath = null } = {}) {
    this.filePath = filePath;
    /** @type {Map<string, object>} accountId -> account */
    this.accounts = new Map();
    /** @type {Map<string, object>} recordId -> record（扁平存，含 _owner） */
    this.records = new Map();
    /** @type {Map<string, object>} deviceId -> device */
    this.devices = new Map();
    if (filePath && existsSync(filePath)) this._load();
  }

  _load() {
    try {
      const data = JSON.parse(readFileSync(this.filePath, 'utf8'));
      this.accounts = new Map(data.accounts || []);
      this.records = new Map(data.records || []);
      this.devices = new Map(data.devices || []);
      nextIdCounter = data.nextIdCounter || 1;
    } catch (e) {
      // 读不动就绝不能"当作空库继续跑"：那样第一次 save() 就会用空状态覆盖掉
      // 磁盘上唯一的一份数据，事故现场直接消失。先把坏文件改名留证，再从空开始。
      const bad = `${this.filePath}.corrupt-${Date.now()}`;
      try {
        renameSync(this.filePath, bad);
        console.error(
          `[onestep-sync] 数据文件损坏，已改名为 ${bad} 保留原件，本次从空库开始。原因: ${e.message}`,
        );
      } catch (renameErr) {
        console.error(
          `[onestep-sync] 数据文件损坏且无法改名保留（${renameErr.message}），` +
            `本次从空库开始，原件可能在下一次保存时被覆盖。原因: ${e.message}`,
        );
      }
    }
  }

  save() {
    if (!this.filePath) return;
    const data = {
      accounts: [...this.accounts],
      records: [...this.records],
      devices: [...this.devices],
      nextIdCounter,
    };
    // 先写临时文件再原子改名：进程在写的中途被杀掉时，主文件要么是旧的完整
    // 版本、要么是新的完整版本，绝不会是半截 JSON（半截 JSON 会让下次 _load
    // 抛异常，于是整库被"从空开始"抹掉）。
    const tmp = `${this.filePath}.tmp`;
    writeFileSync(tmp, JSON.stringify(data), 'utf8');
    renameSync(tmp, this.filePath);
  }

  // ---- 账号 ----

  createAccount({ username, secret }) {
    if (this.findByUsername(username)) {
      throw new SyncError('conflict', '用户名已存在');
    }
    const account = {
      id: genId('acct'),
      username,
      secret,
      createdAt: Date.now(),
    };
    this.accounts.set(account.id, account);
    return account;
  }

  findByUsername(username) {
    for (const a of this.accounts.values()) if (a.username === username) return a;
    return null;
  }

  authAccount(username, secret) {
    const a = this.findByUsername(username);
    if (!a || a.secret !== secret) throw new SyncError('unauthorized', '账号或密钥错误');
    return a;
  }

  // ---- 设备 ----

  registerDevice({ accountId, deviceId, name }) {
    let device = this.devices.get(deviceId);
    if (!device) {
      device = {
        id: deviceId,
        accountId,
        name: name || deviceId,
        createdAt: Date.now(),
        lastCursor: 0,
      };
      this.devices.set(deviceId, device);
    } else if (device.accountId !== accountId) {
      throw new SyncError('forbidden', '设备已绑定到其他账号');
    }
    return device;
  }

  // ---- 记录 ----

  /**
   * 合并一批客户端变更。返回服务端权威的最新记录集合（含被 LWW 保留的）。
   * @param {string} accountId
   * @param {Array<{id, type, version, deleted, payload}>} incoming
   */
  push(accountId, incoming = []) {
    const results = [];
    for (const rec of incoming) {
      if (!rec || typeof rec.id !== 'string') {
        results.push({ ok: false, error: '记录缺少 id' });
        continue;
      }
      const existing = this.records.get(rec.id);
      if (existing && existing._owner !== accountId) {
        results.push({ ok: false, error: '记录不属于该账号' });
        continue;
      }
      // LWW：仅当来件 version 更新才采纳。
      if (!existing || rec.version >= existing.version) {
        const stored = {
          id: rec.id,
          type: rec.type || 'unknown',
          version: rec.version,
          deleted: !!rec.deleted,
          payload: rec.payload ?? null,
          _owner: accountId,
        };
        this.records.set(rec.id, stored);
        results.push({ ok: true, record: stored });
      } else {
        // 客户端落后，回传服务端版本让客户端更新。
        results.push({ ok: true, stale: true, record: existing });
      }
    }
    return results;
  }

  /**
   * 拉取某游标之后（不含游标本身）的全部变更，供设备同步。
   */
  pull(accountId, sinceCursor = 0) {
    const changed = [];
    for (const rec of this.records.values()) {
      if (rec._owner === accountId && rec.version > sinceCursor) changed.push(rec);
    }
    changed.sort((a, b) => a.version - b.version);
    const cursor = changed.length ? changed[changed.length - 1].version : sinceCursor;
    return { changed, cursor };
  }
}

export class SyncError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
