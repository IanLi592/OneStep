#requires -version 5
<#
.SYNOPSIS
  启动跬步自建同步服务端，并打印此刻该在 App 里填的地址。

.DESCRIPTION
  解决两个反复踩的坑：
    1. 应用宝的安卓实例挂在 Hyper-V 虚拟交换机上，宿主机在该交换机上的 IP
       会随应用宝重建网卡而变（实测同一天从 172.31.32.1 变成 172.28.48.1），
       填错就一直卡在"正在登录"；
    2. 服务端默认只在内存里存账号，重启即丢 —— 这里默认落盘到 server\data\sync.json。

.EXAMPLE
  powershell -File scripts\sync-server.ps1
  启动服务端（前台运行，Ctrl+C 停止）。

.EXAMPLE
  powershell -File scripts\sync-server.ps1 -NoRun
  只探测并打印该填的地址，不启动服务。

.NOTES
  本脚本不修改防火墙。缺规则时只打印需要你自己执行的命令。
#>
[CmdletBinding()]
param(
  [int]$Port = 8787,
  [switch]$NoRun,
  [string]$DbFile
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root 'server'
if (-not $DbFile) { $DbFile = Join-Path $serverDir 'data\sync.json' }

# node 的输出是 UTF-8，而 PowerShell 默认按控制台代码页（这台机器是 GBK/936）解码
# 子进程的 stdout，中文会变成乱码。显式改成 UTF-8（读写两个方向都用它）。
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $global:OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

function Write-Line($text, $color) {
  if ($color) { Write-Host $text -ForegroundColor $color } else { Write-Host $text }
}

Write-Line ''
Write-Line '跬步 Onestep · 同步服务端' Cyan
Write-Line ('-' * 46) DarkGray

# --- 1. node 在不在 ---
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Write-Line '未找到 node，可执行文件不在 PATH 里。请先装 Node 18+ 或把它加进 PATH。' Red
  exit 1
}
Write-Line ("node       {0}  ({1})" -f (& node -v), $node.Source)

# --- 2. 该填的地址 ---
# 分类逻辑只在 server\src\addresses.js 里有一份，这里直接调它，避免两边规则漂移。
& node (Join-Path $serverDir 'src\addresses.js') $Port | ForEach-Object { Write-Host $_ }
Write-Line ("数据文件       $DbFile") DarkGray

# --- 3. 端口占用 ---
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($listener) {
  $procName = (Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue).ProcessName
  $healthy = $false
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 3 -UseBasicParsing
    $healthy = ($r.StatusCode -eq 200)
  } catch { }
  if ($healthy) {
    Write-Line ("端口 $Port 已被 $procName (PID $($listener.OwningProcess)) 占用，且 /health 有响应 —— 服务端应该已经在跑了，无需重复启动。") Yellow
    Write-Line '          若应用宝仍连不上，多半是上面那个地址变了，重新按这里打印的填。' DarkGray
    if (-not $NoRun) { exit 0 }
  } else {
    Write-Line ("端口 $Port 已被 $procName (PID $($listener.OwningProcess)) 占用，但它不响应 /health。") Red
    Write-Line '          请先停掉那个进程，或用 -Port 换一个端口。' DarkGray
    exit 1
  }
} else {
  Write-Line ("端口 $Port 空闲。") Green
}

# --- 4. 防火墙入站规则（只检查，不改） ---
$named = Get-NetFirewallRule -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -like "*Onestep Sync*" } |
  Select-Object -First 1
$byPort = $null
if (-not $named) {
  Write-Line '正在扫描防火墙规则（可能要几秒）……' DarkGray
  $byPort = Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -ErrorAction SilentlyContinue |
    Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -eq "$Port" } | Select-Object -First 1
}
if ($named -or $byPort) {
  $n = if ($named) { $named.DisplayName } else { '（按端口匹配到的规则）' }
  Write-Line ("防火墙       已放行 TCP/$Port —— $n") Green
} else {
  Write-Line ("防火墙       没有找到放行 TCP/$Port 的入站规则。") Yellow
  Write-Line '          需要管理员权限，请自己在【管理员 PowerShell】里执行：' DarkGray
  Write-Line ("          New-NetFirewallRule -DisplayName `"Onestep Sync $Port`" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow") DarkGray
}

# --- 5. 启动 ---
if ($NoRun) {
  Write-Line ''
  Write-Line '-NoRun：只探测，不启动。' DarkGray
  exit 0
}

$dataDir = Split-Path -Parent $DbFile
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }

Write-Line ''
Write-Line ("启动服务端中（前台运行，Ctrl+C 停止）…… 在应用宝里点登录/同步即可。") Cyan
Push-Location $serverDir
try {
  $env:PORT = "$Port"
  $env:ONESTEP_SYNC_DB = $DbFile
  & node src/index.js
} finally {
  Pop-Location
}
