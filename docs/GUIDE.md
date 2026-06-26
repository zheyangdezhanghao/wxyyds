# wxyyds 完整使用指南

> **数据安全承诺**：wxyyds **永远不会**删除或修改你的聊天记录。  
> 聊天记录位于 `~/Library/Containers/com.tencent.xinWeChat`，安装过程**只修改** `/Applications/WeChat.app` 内的程序二进制。

---

## 当前支持的微信版本（必读）

offsets 上游：[tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak)（README 写明**当前仅维护 x64**）。

| 架构 | 推荐版本 | Build | 状态 | 功能 |
|------|----------|-------|------|------|
| **Intel (x86_64)** | 4.1.11.21 | **269077** | ✅ 最新已验证 | 防撤回 + 多开；可选 FreezeLock |
| **Apple Silicon (arm64)** | 4.1.5.28 | **32288** | ✅ 已模拟测试验证 | 防撤回 + 多开 |
| Apple Silicon | 4.1.11.x | 269077 | ❌ **不可用** | 无 arm64 offsets（需社区逆向） |
| Apple Silicon | 4.1.10.x | 268853 等 | ❌ **不可用** | manifest 已移除误导条目 |

**重要说明**

- 微信 4.1.11 安装包虽是 Universal Binary，但 **Intel 与 M 芯片使用不同 CPU slice**，offsets 必须分别逆向。
- [WeChatTweak 4.1.11](https://github.com/tanranv5/WeChatTweak) 仅含 **x86_64** 条目，**不是** M 芯片专用。
- **M 系列若已安装 4.1.11**：运行 `bash install.sh` 会提示降级到 **4.1.5.28 (32288)**，**仅替换 WeChat.app，聊天记录保留**。

查看本机是否支持：

```bash
./tools/wxyyds versions          # 按架构列出可用/不可用 build
bash install.sh --check-only     # 只检测，不修改任何文件
```

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
bash install.sh
```

全自动（无确认）：`bash install.sh --yes`

---

## 安装前 Checklist

| 步骤 | 说明 |
|------|------|
| 退出微信 | 必须完全退出；脚本可自动帮你退出 |
| 打开一次微信 | 全新 Mac 请先正常打开微信一次 |
| 完整磁盘访问 | 若报权限错误：**系统设置 → 隐私与安全性 → 完整磁盘访问权限** → 给终端/Cursor 开启 |

---

## 功能说明

| 模块 | 代号 | Intel | Apple Silicon |
|------|------|-------|---------------|
| 防撤回 | RecallGuard | ✅ Patch | ✅ Patch |
| 多开 | MultiGate | ✅ Patch | ✅ Patch |
| 禁自动更新 | FreezeLock | ⚠️ 可选 Framework | ⚠️ 部分版本 / `--with-freeze` |
| 退群监控 | ExitWatch | ❌ 需 Framework | ⚡ Framework 模式 |
| 系统浏览器 | OpenLink | ❌ 需 Framework | ⚡ Framework 模式 |

**默认模式（最稳）**：`bash install.sh` — 仅 Binary Patch，不注入 Framework。

```bash
# 多开
open -n /Applications/WeChat.app

# 可选：注入 Framework（仅 FreezeLock）
bash install.sh --with-freeze
```

---

## Intel 用户：也可用 WeChatTweak 原版

若**只要防撤回 + 多开**，可直接使用上游工具（零 wxyyds 维护成本）：

```bash
brew install tanranv5/tap/wechattweak
wechattweak patch
open -n /Applications/WeChat.app
```

wxyyds 额外提供：一键安装、M 系降级引导、安装后自检、CI 验证、可选 Framework。

同步上游 offsets：

```bash
bash scripts/sync-offsets.sh --apply   # 拉取 WeChatTweak config.json
```

---

## Apple Silicon 特别说明

1. 推荐保持或降级到 **4.1.5.28 (build 32288)**
2. 安装脚本检测到 4.1.11 (269077) 时会**明确说明原因**并引导降级
3. 降级命令：`bash scripts/wechat-download.sh --fallback`（聊天记录保留）

安装后验证：

```bash
bash scripts/smoke-stability.sh
WXYYDS_SMOKE_LAUNCH=1 bash scripts/smoke-stability.sh   # 含 15 秒启动测试
```

---

## 数据与安全边界

| 路径 | 内容 | wxyyds 是否修改 |
|------|------|----------------|
| `~/Library/Containers/com.tencent.xinWeChat` | 聊天记录、数据库 | ❌ **永不** |
| `~/Library/Group Containers/group.com.tencent.xinWeChat` | 共享数据 | ❌ **永不** |
| `/Applications/WeChat.app` | 程序本体 | ✅ 仅 patch 二进制 + 备份 |

安装时会备份到项目内 `backups/wechat-<build>-<时间戳>/`。

---

## 卸载

```bash
bash uninstall.sh
```

---

## CLI 参考

```bash
./tools/wxyyds versions       # 版本支持情况（按架构）
./tools/wxyyds patch          # 手动 patch（安装脚本已包含）
./tools/wxyyds update         # 从 wxyyds 远程更新 offsets
bash install.sh --check-only  # 仅检测，不 patch
bash scripts/sync-offsets.sh  # 对比 WeChatTweak 上游 offsets
bash scripts/audit-secrets.sh # 推送前安全审计
```

---

## 常见问题

**Q: M 系列装了 4.1.11，提示不支持？**  
A: 正常。选 **1** 自动降级到 4.1.5.28，聊天记录不丢。

**Q: Intel 和 M 系列能否都用 4.1.11？**  
A: 目前只有 Intel 可以。M 系列需等社区发布 arm64/269077 offsets。

**Q: 安装后微信打不开？**  
A: 运行 `bash uninstall.sh` 恢复，检查完整磁盘访问权限后重试。

**Q: wxyyds 和 WeChatTweak 关系？**  
A: offsets 来自 [WeChatTweak config.json](https://github.com/tanranv5/WeChatTweak/blob/master/config.json)。wxyyds 在其之上提供安装体验与可选 Framework。

---

## 开发者

```bash
bash scripts/test-all.sh           # 全平台静态验证
bash scripts/test-arm64-sim.sh     # arm64 DMG 模拟 patch 测试
bash scripts/sync-offsets-check.sh # CI：检查是否与上游 drift
```

路线图见 [ROADMAP.md](ROADMAP.md)。贡献 offsets 见 [CONTRIBUTING.md](../CONTRIBUTING.md)。
