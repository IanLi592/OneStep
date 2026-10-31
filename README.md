# 跬步 Onestep

一款面向 **Android + Windows** 双平台的简洁闪记卡（间隔重复）学习应用。

> 不积跬步，无以至千里 —— 每天进步一点点。

借鉴 [Anki](https://github.com/ankitects/anki) 与 [AnkiDroid](https://github.com/ankidroid/Anki-Android)
被验证过的数据模型与学习交互，但以**更简洁干净的界面、更简单的交互**干净重新实现。

## 特性

- **核心学习闭环**：看问题 → 翻面看答案 → 四档打分（忘记/困难/良好/简单），支持撤销。
- **FSRS-7 调度算法**：现代、智能的间隔重复，可配置"期望记忆保持率"。（数值已对照官方参考实现验证）
- **本地优先**：数据全部存本机 SQLite，无需账号、离线可用。
- **牌组与笔记**：嵌套牌组、笔记类型/字段、标签。
- **完形填空（Cloze）**：`{{c1::答案}}` 语法，按序号自动生成多张卡片，复习时挖空/揭示。
- **卡片浏览器**：按文本/标签/状态/牌组搜索过滤，支持挂起与删除。
- **CSV 导入导出**：备份与迁移，兼容 Excel/Windows 换行。
- **APKG 只读导入**：从 Anki 导出的经典 .apkg 迁移牌组（明确不支持新版 zstd 格式并报错）。
- **多设备同步**：自建轻量同步服务端（Node，无外部依赖）+ 客户端，账号 + 设备配对 + 差异合并。
- **统计**：近 7 天复习量、卡片状态分布、记忆保持率、连续打卡。
- **键盘快捷键**（Windows）：空格/回车翻面，1–4 打分，Ctrl+Z 撤销。
- **简洁中文界面**：单一强调色、留白充足、浅色/深色双主题。

## 仓库结构

```
Onestep/
├── app/                    # Flutter 应用（Android + Windows）
│   ├── lib/
│   │   ├── core/
│   │   │   ├── fsrs/       # FSRS-7 调度算法（纯 Dart，数值已验证）
│   │   │   ├── data/       # Drift/SQLite 数据层（表定义 + 数据库）
│   │   │   ├── domain/     # 仓库、调度闭环、CSV、APKG、Cloze、浏览器、统计
│   │   │   └── sync/       # 同步客户端
│   │   ├── features/       # 界面：牌组 / 复习 / 添加卡片 / 浏览器 / 统计 / 设置 / 同步
│   │   └── shared/         # 主题
│   └── test/               # 单元 + 集成测试（56 项，全部通过）
├── server/                 # 自建同步服务端（纯 Node，无外部依赖）
│   ├── src/                # 存储层 + HTTP API
│   └── test/               # 服务端测试（7 项，全部通过）
└── docs/
    ├── 需求说明书.md        # 需求文档
    └── 本地构建说明.md      # 本机构建/工具链说明（重要）
```

## 快速开始

### 应用（Flutter）

本机工具链装在 `.tooling/`（不入库）。**Flutter CLI 需在沙箱外运行**，
纯 Dart 计算可在沙箱内。详见 [docs/本地构建说明.md](docs/本地构建说明.md)。

```powershell
# 环境（重定向缓存到工作区）
$tool='D:\projects\Onestep\.tooling'
$env:APPDATA="$tool\cache"; $env:LOCALAPPDATA="$tool\cache"; $env:PUB_CACHE="$tool\pub-cache"
$env:GRADLE_USER_HOME="$tool\gradle"; $env:JAVA_HOME="$tool\jdk17\jdk-17.0.20.1+1"
$env:ANDROID_HOME="$tool\android-sdk"; $env:PATH="$tool\flutter\bin;$env:JAVA_HOME\bin;$env:PATH"
Set-Location app

flutter analyze          # 静态检查（当前 0 错 0 警）
flutter test             # 运行全部测试
flutter build apk --debug  # 构建安卓 APK
```

### 同步服务端（Node ≥18，无外部依赖）

```powershell
cd server
node test/store.test.js   # 运行服务端测试（7/7 通过）
node src/index.js         # 启动 :8787
```

端点：`POST /register`、`POST /login`、`POST /device`、`POST /sync`。

## 架构要点

- **调度**：FSRS-7，纯 Dart 移植，数值与官方 `fsrs-rs` 参考实现一致（见测试断言）。
- **数据**：Drift（SQLite）。每条记录带 `version`（毫秒时间戳）用于同步的后写胜出(LWW)合并。
- **同步**：哑终端云(dumb-cloud)模型。客户端本地 SQLite 为准，服务端只做版本去重合并与
  游标拉取；冲突副本由客户端保留，绝不静默丢数据。
- **合规**：不复制 Anki(AGPL)/AnkiDroid(GPL) 源码，仅借鉴数据模型与交互；FSRS 为 MIT 许可。

## 已知限制

- Windows 桌面打包需本机安装 Visual Studio C++ 工作负载 + 开启开发者模式（符号链接）。
- APKG 只读导入尚未实现（计划中）。
- 媒体（图片/音频）与 TTS 尚未实现。

## 许可证

MIT（应用自身代码）。第三方依赖与参考实现各自遵循其许可证。
