import os from 'node:os';
import { pathToFileURL } from 'node:url';

/**
 * 从本机网卡算出「App 里该填的地址」。
 *
 * 为什么需要：服务端默认打印 localhost，但从应用宝里的安卓应用看，localhost 指的是
 * 那个虚拟机自己，永远连不到宿主机。填错的典型症状是界面卡在"正在登录…"
 * （TCP 连不出去也无人拒绝），极易误判成防火墙问题。
 *
 * 分类规则（都是实测踩出来的）：
 *  - 应用宝的安卓实例挂在 Hyper-V 的 `vEthernet (MyApps vSwitch)` 上，
 *    宿主机在该交换机上的地址才是虚拟机能够到的地址；
 *  - 必须排除 `vEthernet (WSL ...)` —— 它也是 vEthernet，但虚拟机不在那个段里；
 *  - 必须排除 `tun0` 这类 VPN 隧道：它是 IPv4 且非 internal，列出来会误导；
 *  - 必须排除 169.254.*（DHCP 失败时的 APIPA 地址，不可路由）。
 *
 * 只做识别，不做任何网络操作。
 */

/** 应用宝虚拟交换机（名字里带 MyApps）。 */
const VM_PATTERN = /myapps/i;
/** 明确不是安卓虚拟机网卡的适配器：Hyper-V 其它交换机、VPN 隧道、回环等。 */
const NON_VM_VIRTUAL =
  /^(vEthernet|Loopback|isatap|tun|tap|wg|dn|Bluetooth Network|Virtual)/i;

function isApipa(address) {
  return address.startsWith('169.254.');
}

/** Node 老版本 family 是数字 4，新版本是字符串 'IPv4'，两种都要认。 */
function isIPv4(addr) {
  return addr.family === 'IPv4' || addr.family === 4;
}

/**
 * 把 os.networkInterfaces() 的输出分成三类。
 * @param {object} [interfaces] 默认取真实网卡；测试可注入假数据。
 * @returns {{vm: Array, lan: Array, loopback: Array}}
 */
export function classifyInterfaces(interfaces = os.networkInterfaces()) {
  const vm = [];
  const lan = [];
  const loopback = [];

  for (const [name, addrs] of Object.entries(interfaces)) {
    for (const a of addrs ?? []) {
      if (!isIPv4(a)) continue;
      if (a.internal) {
        loopback.push({ name, address: a.address });
        continue;
      }
      if (isApipa(a.address)) continue;
      if (VM_PATTERN.test(name)) {
        vm.push({ name, address: a.address });
      } else if (NON_VM_VIRTUAL.test(name)) {
        // WSL / VPN / 隧道 / 回环：不推荐给用户。
      } else {
        lan.push({ name, address: a.address });
      }
    }
  }

  return { vm, lan, loopback };
}

/**
 * 只返回"该填哪个地址"的几行（不含标题与数据文件行）。
 * 服务端横幅和 scripts\sync-server.ps1 都复用这一份，避免两边规则漂移。
 * @param {{port: number, interfaces?: object}} [opts]
 * @returns {string[]}
 */
export function addressLines({ port, interfaces } = {}) {
  const { vm, lan } = classifyInterfaces(interfaces);
  const lines = [];

  if (vm.length) {
    for (const i of vm) {
      lines.push(`  应用宝(安卓虚拟机)填   http://${i.address}:${port}`);
    }
  } else {
    lines.push(
      '  应用宝(安卓虚拟机)填   未找到 MyApps 虚拟网卡。',
      '                        应用宝没运行过时不会有这块网卡：先启动一次应用宝，再重启服务端。',
    );
  }

  for (const i of lan) {
    lines.push(`  真手机(同 Wi-Fi)填    http://${i.address}:${port}   (${i.name})`);
  }

  lines.push(`  本机自测              http://127.0.0.1:${port}/health`);
  return lines;
}

/**
 * 生成启动横幅的行。
 * @param {{port: number, dataFile: string|null, interfaces?: object}} opts
 * @returns {string[]}
 */
export function startupBanner({ port, dataFile = null, interfaces } = {}) {
  const lines = [`Onestep 同步服务端已启动 · 端口 ${port}`, ...addressLines({ port, interfaces })];

  if (dataFile) {
    lines.push(`  数据文件              ${dataFile}`);
  } else {
    lines.push(
      '  数据文件              未启用持久化（纯内存）！进程重启会清空全部账号与同步记录，',
      '                        客户端只会表现为"登录不上原账号"。',
    );
  }
  return lines;
}

// 直接运行本文件时只打印该填的地址（给 scripts/sync-server.ps1 调用）。
// 地址分类只有这一份实现：PowerShell 里不再重复写一遍。
const isMain =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  const port = Number(process.argv[2] ?? process.env.PORT ?? 8787);
  for (const line of addressLines({ port })) console.log(line);
}
