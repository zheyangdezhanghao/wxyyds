# wxyyds 完整使用指南

> **数据安全承诺**：wxyyds **永远不会**删除或修改你的聊天记录。  
> 聊天记录位于 `~/Library/Containers/com.tencent.xinWeChat`，安装过程**只修改** `/Applications/WeChat.app` 内的程序二进制。

---

## 当前支持的微信版本（必读）

offsets 上游：[tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak)（README 写明**当前仅维护 x64**）。

| 架构 | 推荐版本 | Build | 状态 | 功能 |
|------|----------|-------|------|------|
| **Intel (x86_64)** | 4.1.11.21 | **269077** | ✅ 最新已验证 | Patch + Framework（菜单、禁更新） |
| **Apple Silicon (arm64)** | 4.1.5.28 | **32288** | ✅ 已模拟测试验证 | Patch；Framework 可选 |
| Apple Silicon | 4.1.11.x | 269077 | ❌ **不可用** | 无 arm64 offsets（需社区逆向） |

**重要说明**

- 微信 4.1.11 安装包虽是 Universal Binary，但 **Intel 与 M 芯片使用不同 CPU slice**，offsets 必须分别逆向。
- [WeChatTweak 4.1.11](https://github.com/tanranv5/WeChatTweak) 仅含 **x86_64** 条目，**不是** M 芯片专用。
- **M 系列若已安装 4.1.11**：运行 `bash install.sh` 会提示降级到 **4.1.5.28 (32288)**，**仅替换 WeChat.app，聊天记录保留**。

查看本机是否支持：

```bash
./tools/wxyyds versions          # 按架构列出可用/不可用 build
bash install.sh --check-only     # 只检测，不修改任何文件
```

Intel 专篇：[INTEL-GUIDE.md](INTEL-GUIDE.md) · Apple Silicon：[APPLE-SILICON.md](APPLE-SILICON.md)

---

## 安装模式一览

wxyyds 提供两种安装深度，请按需求选择：

### 模式 A：Patch-only（默认，最稳）

```bash
bash install.sh
# 或双击 一键安装.command
```

- 仅修改 `wechat.dylib` 二进制
- **RecallGuard**（防撤回）+ **MultiGate**（多开）
- 不注入 Framework，无菜单栏
- 适合：只要防撤回 + 多开，追求最低风险

### 模式 B：Framework 稳定模式（Intel 269077 推荐）

```bash
bash install.sh --with-framework
# 全自动：bash install.sh --with-framework --yes
```

- 自动编译并注入 **WXYydsHook v0.6.1**（`WXYydsHook/build.sh`）
- 防撤回仍用**静态 Patch**（RecallGuard + MultiGate），稳定可靠
- 额外获得：**FreezeLock**（禁更新）、**wxyyds 助手**菜单栏
- 菜单内可开关：撤回提醒、退群监控、系统浏览器、多开
- **默认关闭**：撤回提醒（`recallNotify`）、聊天内灰字（`recallInChat`），避免启动卡顿或崩溃

配置保存在 `~/.wxyyds/config.json`，菜单切换后部分功能需重启微信。

### 模式 C：Framework 实验模式（聊天内灰字）

```bash
WXYYDS_RECALL_INCHAT=1 bash install.sh --with-framework
```

- 在模式 B 基础上，尝试通过**指针 Hook** 实现 SovietExtension 风格的「聊天内灰色系统消息」
- ⚠️ **已知问题**：登录后约 10–20 秒可能闪退或卡顿，**不推荐日常使用**
- 仅 patch `multiInstance`，防撤回改由指针 Hook 路径处理
- 适合开发者验证 RE 偏移，普通用户请用模式 B

---

## 快速安装

### 方法一：双击（小白推荐）

1. [下载项目](https://github.com/zheyangdezhanghao/wxyyds/archive/refs/heads/main.zip) 或 `git clone`
2. **完全退出微信**
3. 双击 **`一键安装.command`**
4. 若被拦截：右键 → **打开** → 确认

### 方法二：一行命令

```bash
curl -fsSL https://raw.githubusercontent.com/zheyangdezhanghao/wxyyds/main/scripts/bootstrap.sh | bash
```

### 方法三：手动

```bash
git clone https://github.com/zheyangdezhanghao/wxyyds.git
cd wxyyds
bash install.sh --with-framework   # Intel 269077 推荐
```

全自动（无确认）：`bash install.sh --yes`

---

## 安装前 Checklist

| 步骤 | 说明 |
|------|------|
| 退出微信 | 必须完全退出；脚本可自动帮你退出 |
| 打开一次微信 | 全新 Mac 请先正常打开微信一次 |
| 完整磁盘访问 | 若报权限错误：**系统设置 → 隐私与安全性 → 完整磁盘访问权限** → 给终端/Cursor 开启 |
| Xcode CLT | Framework 模式需 `xcode-select --install` 或 Xcode（编译 WXYydsHook） |

---

## 功能说明

| 模块 | 代号 | Patch-only | Framework | 说明 |
|------|------|------------|-----------|------|
| 防撤回 | RecallGuard | ✅ | ✅ | 静态 Patch，`B801000000C3` |
| 多开 | MultiGate | ✅ | ✅ | NOP 单实例检测 |
| 禁自动更新 | FreezeLock | — | ✅ 默认开 | Sparkle Swizzle |
| 菜单栏助手 | MenuBar | — | ✅ | 「wxyyds 助手」 |
| 撤回提醒 | RecallNotify | — | ⚠️ 默认关 | 弹窗 + 系统通知 |
| 聊天内灰字 | RecallInChat | — | 🧪 实验 | 需 `WXYYDS_RECALL_INCHAT=1` |
| 退群监控 | ExitWatch | — | ⚠️ 默认关 | 菜单开启 |
| 系统浏览器 | OpenLink | — | ⚠️ 默认关 | 菜单开启；v0.6.1 修复链接卡死 |

### wxyyds 助手菜单

Framework 注入成功后，微信菜单栏会出现 **「wxyyds 助手」**：

- 阻止更新（FreezeLock）
- 撤回提醒（RecallNotify）
- 退群监控（ExitWatch）
- 使用系统浏览器（OpenLink）
- 多开（`open -n`）

### 与 SovietExtension 的差异

| 功能 | SovietExtension | wxyyds |
|------|-----------------|--------|
| 防撤回 | Hook / Patch | ✅ 静态 Patch（稳定） |
| 多开 | Patch | ✅ Patch |
| 禁更新 | Swizzle | ✅ FreezeLock |
| 菜单栏 | ✅ | ✅ |
| 撤回系统通知 | ✅ | ✅（默认关，菜单开） |
| 聊天内灰字 | ✅ | 🧪 实验（269077 指针 Hook，不稳定） |

参考实现：[SovietExtension RevokePatch.mm](https://github.com/MustangYM/SovietExtension)

### 多开

```bash
open -n /Applications/WeChat.app
```

---

## Intel 用户

详见 **[INTEL-GUIDE.md](INTEL-GUIDE.md)**。

简要：

- 推荐 **build 269077**（4.1.11.21）
- 日常推荐：`bash install.sh --with-framework`
- 只要防撤回+多开：`bash install.sh` 或 `brew install tanranv5/tap/wechattweak && wechattweak patch`

---

## Apple Silicon 特别说明

详见 **[APPLE-SILICON.md](APPLE-SILICON.md)**。

1. 推荐保持或降级到 **4.1.5.28 (build 32288)**
2. 安装脚本检测到 4.1.11 (269077) 时会**明确说明原因**并引导降级
3. 降级命令：`bash scripts/wechat-download.sh --fallback`（聊天记录保留）
4. Framework 模式：`bash install.sh --with-framework`（32288 已验证 Patch）

安装后验证：

```bash
bash scripts/smoke-stability.sh
WXYYDS_SMOKE_LAUNCH=1 bash scripts/smoke-stability.sh   # 含短时启动测试
```

---

## 数据与安全边界

| 路径 | 内容 | wxyyds 是否修改 |
|------|------|----------------|
| `~/Library/Containers/com.tencent.xinWeChat` | 聊天记录、数据库 | ❌ **永不** |
| `~/Library/Group Containers/group.com.tencent.xinWeChat` | 共享数据 | ❌ **永不** |
| `/Applications/WeChat.app` | 程序本体 | ✅ 仅 patch 二进制 + 备份 |
| `~/.wxyyds/config.json` | 模块开关配置 | ✅ Framework 模式写入 |

安装时会备份 WeChat.app 到 `backups/wechat-<build>-<时间戳>/`（或环境变量 `WXYYDS_BACKUP_DIR` 指定目录）。

---

## 卸载

```bash
bash uninstall.sh
```

从备份恢复：`backups/` 目录内有安装前的完整 `.app` 副本。

---

## CLI 参考

```bash
./tools/wxyyds versions       # 版本支持情况（按架构）
./tools/wxyyds patch          # 手动 patch（安装脚本已包含）
./tools/wxyyds update         # 从 wxyyds 远程更新 offsets
bash install.sh --check-only  # 仅检测，不 patch
bash install.sh --help        # 全部安装选项
bash scripts/sync-offsets.sh  # 对比 WeChatTweak 上游 offsets
bash scripts/audit-secrets.sh # 推送前安全审计
```

### install.sh 常用选项

| 选项 | 说明 |
|------|------|
| `--yes` / `-y` | 跳过所有确认 |
| `--with-framework` | 注入 WXYydsHook（同 `--with-freeze`） |
| `--patch-only` | 仅 Binary Patch（默认） |
| `--upgrade-wechat` | 从 canc3s 下载并安装支持版本 |
| `--check-only` | 只检测，不修改 |
| `--force` | 跳过版本检查 |
| `--app=PATH` | 指定 WeChat.app 路径 |

环境变量：

| 变量 | 说明 |
|------|------|
| `WXYYDS_RECALL_INCHAT=1` | 启用实验性聊天内灰字（不推荐日常） |
| `WXYYDS_BACKUP_DIR` | 自定义备份目录 |
| `WXYYDS_APP` | 自定义 WeChat.app 路径（自检脚本） |

---

## 常见问题

**Q: M 系列装了 4.1.11，提示不支持？**  
A: 正常。选 **1** 自动降级到 4.1.5.28，聊天记录不丢。

**Q: Intel 和 M 系列能否都用 4.1.11？**  
A: 目前只有 Intel 可以。M 系列需等社区发布 arm64/269077 offsets。

**Q: 点击链接微信卡死？**  
A: v0.6.1 已修复 OpenLink 无限递归。请退出微信后 `bash install.sh --with-framework --yes` 重装。OpenLink 默认关闭，需在菜单手动开启。

**Q: Framework 模式登录后闪退？**  
A: 若曾用 `WXYYDS_RECALL_INCHAT=1` 安装，请改回稳定模式：`bash install.sh --with-framework --yes`（不带该环境变量）。确认 `~/.wxyyds/config.json` 中 `recallInChat` 为 `false`。

**Q: 微信很卡？**  
A: 稳定模式已默认关闭 `recallNotify` 的全局 selector 扫描。若仍卡，先用 Patch-only：`bash install.sh --patch-only --yes`。

**Q: 安装后微信打不开？**  
A: 运行 `bash uninstall.sh` 恢复，检查完整磁盘访问权限后重试。

**Q: 如何确认 Patch 成功？**  
A: `bash scripts/smoke-stability.sh`；Framework 日志：`tail -f /tmp/wxyyds-hook.log`，稳定模式应看到 `RevokeInChat: module disabled`。

**Q: wxyyds 和 WeChatTweak 关系？**  
A: offsets 来自 [WeChatTweak config.json](https://github.com/tanranv5/WeChatTweak/blob/master/config.json)。wxyyds 在其之上提供安装体验、Framework 与 CI 验证。

---

## 开发者

```bash
bash WXYydsHook/build.sh           # 编译 Framework
bash scripts/test-all.sh           # 全平台静态验证
bash scripts/test-recall-inchat.sh # 269077 灰字 Hook 测试
bash scripts/test-arm64-sim.sh     # arm64 DMG 模拟 patch 测试
bash scripts/sync-offsets-check.sh # CI：检查是否与上游 drift
```

路线图见 [ROADMAP.md](ROADMAP.md)。贡献 offsets 见 [CONTRIBUTING.md](../CONTRIBUTING.md)。
