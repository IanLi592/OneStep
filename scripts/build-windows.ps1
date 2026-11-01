# 本地构建 Windows 桌面 exe（需先装一次 VS Build Tools）。
#
# 前置（每台机器只需做一次，需管理员）：
#   1) 安装 "Visual Studio 2022 Build Tools"，勾选工作负载：
#        ✅ 使用 C++ 的桌面开发（含 MSVC、Windows SDK、CMake 工具）
#      下载：https://visualstudio.microsoft.com/downloads/ → "Build Tools for Visual Studio 2022"
#      （命令行静默安装，需管理员 PowerShell）：
#        vs_buildTools.exe --quiet --wait --norestart `
#          --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended
#
#   2) 开启开发者模式（符号链接，Flutter 插件需要）：
#        设置 → 系统 → 开发者选项 → 打开"开发人员模式"
#      （或管理员 PowerShell：）
#        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
#          -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
#
# 之后运行本脚本即可产出 exe。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot   # 仓库根
$app  = Join-Path $root 'app'

Write-Output '=== 环境自检 ==='
# 找 MSVC（vswhere）
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
  $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($vsPath) { Write-Output "MSVC: $vsPath" } else { Write-Warning '未找到 MSVC，请确认安装了"使用 C++ 的桌面开发"工作负载' }
} else {
  Write-Warning '未找到 vswhere（未安装 VS Build Tools）'
}

Set-Location $app
Write-Output '=== flutter pub get ==='
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'pub get 失败' }

Write-Output '=== flutter build windows --release ==='
# --no-tree-shake-icons: 图标子集化会误剪部分图标字形(如 create_new_folder_outlined),
# 导致图标空白;关掉它保证所有图标完整(字体约 +1.6MB)。
flutter build windows --release --no-tree-shake-icons
if ($LASTEXITCODE -ne 0) { throw '构建失败（确认开发者模式已开启、MSVC 已装）' }

$out = Join-Path $app 'build\windows\runner\Release'
Write-Output "`n✅ 构建完成：$out"
Get-ChildItem $out -Filter '*.exe' | ForEach-Object { Write-Output ("  " + $_.Name + "  " + [math]::Round($_.Length/1MB,1) + " MB") }
Write-Output "`n把 Release 目录整个打包分发即可（含 onestep.exe 与其依赖 DLL）。"
