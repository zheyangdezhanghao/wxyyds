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
  <img src="https://img.shields.io/badge/arch-x86__64%20%2B%20arm64-07C160?style=flat-square" alt="arch" />
  <img src="https://img.shields.io/badge/WeChat-4.0%2B-07C160?style=flat-square" alt="wechat" />
  <img src="https://img.shields.io/badge/license-AGPL--3.0-blue?style=flat-square" alt="license" />
</p>

---

**wxyyds** 是面向 macOS 的微信增强助手。防撤回、多开、禁更新、菜单栏助手，一切由你决定。

## 功能

| 模块 | 代号 | 默认模式 | Framework 模式 | 说明 |
|------|------|----------|----------------|------|
| 消息防撤回 | **RecallGuard** | ✅ 稳定 | ✅ 稳定 | 静态 Patch，原消息保留 |
| 客户端多开 | **MultiGate** | ✅ 稳定 | ✅ 稳定 | `open -n /Applications/WeChat.app` |
| 阻止更新 | **FreezeLock** | — | ✅ 稳定 | Runtime Swizzle，菜单可开关 |
| 菜单栏助手 | **MenuBar** | — | ✅ | 「wxyyds 助手」菜单 |
| 撤回提醒 | **RecallNotify** | — | ⚠️ 默认关 | 弹窗 + 系统通知（菜单开启） |
| 聊天内灰字 | **RecallInChat** | — | 🧪 实验 | 需 `WXYYDS_RECALL_INCHAT=1`，可能不稳定 |
| 退群监控 | **ExitWatch** | — | ⚠️ 默认关 | Framework 菜单开启 |
| 系统浏览器 | **OpenLink** | — | ⚠️ **默认关** | 菜单手动开启；v0.6.1 修复链接卡死 |

> **Intel (x86_64)**：推荐 **4.1.11 / build 269077** — Patch + 可选 Framework  
> **Apple Silicon (arm64)**：推荐 **4.1.5.28 / build 32288** — M 系暂不支持 4.1.11  
> 完整说明见 **[docs/GUIDE.md](docs/GUIDE.md)** · Intel 专篇 **[docs/INTEL-GUIDE.md](docs/INTEL-GUIDE.md)**

## 安装模式

| 命令 | 适用场景 |
|------|----------|
| `bash install.sh` | **默认（最稳）**：仅 Binary Patch（防撤回 + 多开） |
| `bash install.sh --with-framework` | **推荐 Intel 269077**：注入 WXYydsHook（菜单 + 禁更新 + 稳定防撤回） |
| `WXYYDS_RECALL_INCHAT=1 bash install.sh --with-framework` | **实验**：聊天内灰字（可能登录后崩溃，不推荐日常使用） |

安装脚本会自动编译 `WXYydsHook`（若尚未构建）。全自动无确认：`bash install.sh --yes`

## 快速安装

### 🟢 小白推荐：双击安装

1. [下载本项目](https://github.com/zheyangdezhanghao/wxyyds/archive/refs/heads/main.zip) 或 `git clone`
2. **完全退出微信**
3. 双击 **`一键安装.command`**
4. 若被拦截：右键 → **打开** → 确认

> 详细说明见 **[docs/GUIDE.md](docs/GUIDE.md)**

### 仅检测（不修改微信）

```bash
bash install.sh --check-only
```

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

### 先打开一次微信

如果是全新安装，请先手动打开一次微信，再运行 `install.sh`，否则可能提示「已损坏，无法打开」。

### 权限

`系统设置 → 隐私与安全性` 为当前终端开启 **完整磁盘访问权限**。

### 安装后验证

```bash
bash scripts/smoke-stability.sh
tail -f /tmp/wxyyds-hook.log   # Framework 模式日志
```

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
├── WXYydsHook/             # Framework 源码（菜单、禁更新、撤回提醒等）
│   └── build.sh            # 编译 WXYyds.framework
├── scripts/
│   ├── bootstrap.sh        # 一行 curl 在线安装
│   ├── smoke-stability.sh  # 安装后自检
│   └── wechat-download.sh  # canc3s 版本下载器
├── offsets/
│   ├── config.json         # 合并自 tanranv5 的 patch offsets
│   ├── hook_269077.json    # Intel 灰字指针 Hook 偏移（实验）
│   └── manifest.json       # 版本 ↔ canc3s release 映射
├── tools/
│   ├── wxyyds              # CLI
│   └── patcher.py          # Mach-O 补丁引擎
├── Rely/
│   ├── supported_versions.txt
│   └── Plugin/             # WXYyds.framework 产物目录
└── .github/workflows/
```

## 版本适配

| 架构 | 推荐 build | 微信版本 | 状态 |
|------|-----------|----------|------|
| Intel x86_64 | 269077 | 4.1.11.21 | ✅ 最新 + Framework |
| Apple Silicon arm64 | 32288 | 4.1.5.28 | ✅ 已验证 |
| Apple Silicon | 269077 | 4.1.11 | ❌ 无 arm64 offsets |

offsets 上游：[tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak)（4.1.11 **仅 x86_64**）

Intel 只要防撤回+多开也可直接用：`brew install tanranv5/tap/wechattweak && wechattweak patch`

同步上游：`bash scripts/sync-offsets.sh --apply`

微信安装包：[canc3s/wechat-versions](https://github.com/canc3s/wechat-versions/releases)

**新版本 offsets 需社区贡献**，见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 数据安全

| 路径 | wxyyds 是否修改 |
|------|----------------|
| `~/Library/Containers/com.tencent.xinWeChat` | ❌ **永不**（聊天记录） |
| `/Applications/WeChat.app` | ✅ 仅 patch 二进制 + 备份 |

## 顺手可加的好用功能（路线图）

见 [docs/ROADMAP.md](docs/ROADMAP.md)。

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
