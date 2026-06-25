# wxyyds

<p align="center">
  <img src="assets/logo.svg" width="320" alt="wxyyds logo" />
</p>

<p align="center">
  <strong>一个极客的理想之地</strong><br/>
  <em>Where Geeks Take Control — 微信，由你掌控</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-1A1A2E?style=flat-square" alt="platform" />
  <img src="https://img.shields.io/badge/arch-Universal%20(arm64%20%2B%20x86__64)-07C160?style=flat-square" alt="arch" />
  <img src="https://img.shields.io/badge/WeChat-4.0%2B-07C160?style=flat-square" alt="wechat" />
  <img src="https://img.shields.io/badge/license-AGPL--3.0-blue?style=flat-square" alt="license" />
</p>

---

**wxyyds** 是面向 macOS 的微信增强助手。防撤回、多开、禁更新、退群监控，一切由你决定。

## 功能

| 模块 | 代号 | 状态 | 说明 |
|------|------|------|------|
| 消息防撤回 | **RecallGuard** | ✅ 稳定 | 删不掉的记忆 |
| 客户端多开 | **MultiGate** | ✅ 稳定 | `open -n /Applications/WeChat.app` |
| 阻止更新 | **FreezeLock** | ✅ 稳定 | arm64 全量；Intel patch 模式 |
| 退群监控 | **ExitWatch** | ⚡ Framework | Apple Silicon + Framework 模式 |
| 系统浏览器 | **OpenLink** | ⚡ Framework | 链接用系统浏览器打开 |
| 自动抢红包 | **RedRush** | 🔒 默认关闭 | 后续可选模块 |
| 群助手 | **GroupBot** | 🔒 默认关闭 | 后续可选模块 |

> **Intel (x86_64)**：Binary Patch 模式，防撤回 + 多开（offsets 持续同步 [tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak)）  
> **Apple Silicon (arm64)**：Patch 模式 + 可选 Framework 全功能

## 快速安装

### 🟢 小白推荐：双击安装

1. [下载本项目](https://github.com/zheyangdezhanghao/wxyyds/archive/refs/heads/main.zip) 或 `git clone`
2. **完全退出微信**
3. 双击 **`一键安装.command`**
4. 若被拦截：右键 → **打开** → 确认

> 详细图文说明见 [docs/快速安装.md](docs/快速安装.md)

### 🟢 一行命令（自动下载 + 安装）

```bash
curl -fsSL https://raw.githubusercontent.com/zheyangdezhanghao/wxyyds/main/scripts/bootstrap.sh | bash
```

### 手动安装

```bash
git clone https://github.com/zheyangdezhanghao/wxyyds.git
cd wxyyds
bash install.sh
```

安装脚本会自动：

1. 检查环境（python3、offsets）
2. 检测 CPU 架构（arm64 / x86_64）
3. 提示退出微信（可自动帮你退出）
4. 检测微信 `CFBundleVersion`，不支持时**交互式升级**（聊天记录保留）
5. 备份 → 打补丁 → 重签名 → 安装后自检

全自动（无确认）：`bash install.sh --yes`

### 先打开一次微信

如果是全新安装，请先手动打开一次微信，再运行 `install.sh`，否则可能提示「已损坏，无法打开」。

### 权限

`系统设置 → 隐私与安全性` 为当前终端开启 **完整磁盘访问权限**。

## CLI

```bash
# 查看支持版本
./tools/wxyyds versions

# 手动 Patch（安装脚本已包含）
./tools/wxyyds patch

# 远程更新 offsets 数据库
./tools/wxyyds update
```

## 多开

```bash
open -n /Applications/WeChat.app
```

## 卸载

```bash
bash uninstall.sh
```

## 项目结构

```
wxyyds/
├── 一键安装.command        # 双击傻瓜安装（小白推荐）
├── install.sh              # 一键安装
├── uninstall.sh            # 卸载
├── scripts/
│   ├── bootstrap.sh        # 一行 curl 在线安装
│   └── smoke-stability.sh  # 安装后自检
├── offsets/
│   ├── config.json         # 合并自 tanranv5 的 patch offsets
│   └── manifest.json       # 版本 ↔ canc3s release 映射
├── tools/
│   ├── wxyyds              # CLI
│   └── patcher.py          # Mach-O 补丁引擎
├── scripts/
│   └── wechat-download.sh  # canc3s 版本下载器
├── Rely/
│   ├── supported_versions.txt
│   └── Plugin/             # WXYyds.framework（可选）
└── .github/workflows/
```

## 版本适配

offsets 合并自：

- [tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak) — 持续维护（含 4.1.11 / build 269077）
- [SovietExtension](https://github.com/MustangYM/SovietExtension) — Framework 架构参考

微信安装包归档：[canc3s/wechat-versions](https://github.com/canc3s/wechat-versions/releases)

**新版本适配需社区贡献 offsets**，见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 顺手可加的好用功能（路线图）

| 功能 | 难度 | 说明 |
|------|------|------|
| 链接系统浏览器 | ★★☆ | Framework 模式已有（OpenLink） |
| 退群提醒 | ★★☆ | Framework 模式已有（ExitWatch） |
| 消息时间戳显示 | ★★☆ | Hook MessageWrap 字段 |
| 免打扰群折叠增强 | ★★☆ | UI Hook |
| Alfred / Raycast 集成 | ★★☆ | sunnyyoung 已有实践 |
| 禁止「正在输入」状态 | ★★★ | 需定位 typing 回调 |
| 聊天记录导出快捷键 | ★★★ | 菜单 + 已有 API Hook |
| 自动翻译（实验） | ★★★ | 可选模块 |

## 免责声明

本项目**仅供学习与技术交流**，禁止用于任何违法用途。使用本工具可能违反微信用户协议，存在封号风险，请自行承担后果。

## Thanks

wxyyds 站在巨人的肩膀上：

- [SovietExtension](https://github.com/MustangYM/SovietExtension) — 插件架构灵感
- [WeChatTweak](https://github.com/sunnyyoung/WeChatTweak) — 二进制 Patch 引擎
- [tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak) — 持续维护的 offsets
- [wechat-versions](https://github.com/canc3s/wechat-versions) — 微信版本归档

**For Geeks. For Freedom.**

## License

[AGPL-3.0](LICENSE)
