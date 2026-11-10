import test from 'node:test';
import assert from 'node:assert/strict';

import { classifyInterfaces, startupBanner, addressLines } from '../src/addresses.js';

/**
 * 地址识别测试：全部用注入的假网卡数据，不依赖跑测试这台机器的网络状态。
 * 关键是锁死两条实测踩出来的误判：把 WSL 的 vEthernet 当成安卓虚拟机网卡、
 * 把 VPN 隧道地址当成"手机可连的局域网地址"。
 */

const fake = {
  'vEthernet (MyApps vSwitch)': [
    { address: '172.28.48.1', netmask: '255.255.240.0', family: 'IPv4', internal: false },
  ],
  'vEthernet (WSL (Hyper-V firewall))': [
    { address: '172.30.0.1', netmask: '255.255.240.0', family: 'IPv4', internal: false },
  ],
  WLAN: [{ address: '192.168.50.220', netmask: '255.255.255.0', family: 'IPv4', internal: false }],
  tun0: [{ address: '172.19.0.1', netmask: '255.255.255.252', family: 'IPv4', internal: false }],
  'Loopback Pseudo-Interface 1': [
    { address: '127.0.0.1', netmask: '255.0.0.0', family: 'IPv4', internal: true },
  ],
  以太网: [{ address: '169.254.12.34', netmask: '255.255.0.0', family: 'IPv4', internal: false }],
};

test('MyApps 虚拟交换机被认成虚拟机地址，WSL 的 vEthernet 不算', () => {
  const { vm } = classifyInterfaces(fake);
  assert.deepEqual(vm.map((i) => i.address), ['172.28.48.1']);
});

test('VPN 隧道与 APIPA 不会被当成手机可连的局域网地址', () => {
  const { lan } = classifyInterfaces(fake);
  assert.deepEqual(lan.map((i) => i.address), ['192.168.50.220']);
});

test('回环接口单独归类，不进 lan', () => {
  const { lan, loopback } = classifyInterfaces(fake);
  assert.equal(lan.some((i) => i.address === '127.0.0.1'), false);
  assert.deepEqual(loopback.map((i) => i.address), ['127.0.0.1']);
});

test('老版本 Node 的 family: 4 也能识别', () => {
  const { lan } = classifyInterfaces({
    WLAN: [{ address: '10.0.0.5', family: 4, internal: false }],
  });
  assert.deepEqual(lan.map((i) => i.address), ['10.0.0.5']);
});

test('IPv6 地址被忽略', () => {
  const { lan, vm } = classifyInterfaces({
    WLAN: [{ address: 'fe80::1', family: 'IPv6', internal: false }],
  });
  assert.equal(lan.length, 0);
  assert.equal(vm.length, 0);
});

test('横幅给出可直接照抄的 URL 与端口', () => {
  const lines = startupBanner({ port: 8787, dataFile: 'D:\\x\\sync.json', interfaces: fake });
  const text = lines.join('\n');
  assert.match(text, /应用宝\(安卓虚拟机\)填\s+http:\/\/172\.28\.48\.1:8787/);
  assert.match(text, /真手机\(同 Wi-Fi\)填\s+http:\/\/192\.168\.50\.220:8787/);
  assert.match(text, /http:\/\/127\.0\.0\.1:8787\/health/);
  assert.match(text, /D:\\x\\sync\.json/);
  assert.equal(text.includes('172.30.0.1'), false, 'WSL 地址不该出现在横幅里');
  assert.equal(text.includes('172.19.0.1'), false, 'VPN 地址不该出现在横幅里');
});

test('addressLines 只出地址行，不含标题与数据文件（脚本复用它）', () => {
  const text = addressLines({ interfaces: fake }).join('\n').replace(/http:\/\/\S+/g, 'URL');
  assert.match(text, /应用宝\(安卓虚拟机\)填\s+URL/);
  assert.equal(text.includes('Onestep 同步服务端已启动'), false);
  assert.equal(text.includes('数据文件'), false);
});

test('没有 MyApps 网卡时，提示先启动一次应用宝', () => {
  const noVm = { WLAN: fake.WLAN };
  const text = startupBanner({ port: 8787, dataFile: 'x', interfaces: noVm }).join('\n');
  assert.match(text, /未找到 MyApps 虚拟网卡/);
  assert.match(text, /先启动一次应用宝/);
});

test('未启用持久化时横幅要警告，而不是安静地跑', () => {
  const text = startupBanner({ port: 8787, dataFile: null, interfaces: fake }).join('\n');
  assert.match(text, /未启用持久化/);
  assert.match(text, /重启会清空全部账号/);
});
