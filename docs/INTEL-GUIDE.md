# Intel 用户指南

本文档面向 **Intel Mac (x86_64)** 用户。通用安装与 FAQ 见 **[GUIDE.md](GUIDE.md)**。

---

## 推荐版本

| 项目 | 值 |
|------|-----|
| 微信版本 | 4.1.11.21 |
| Build | **269077** |
| 二进制 | `Contents/Resources/wechat.dylib` |
| 安装包 | [canc3s v4.1.11.21-mac](https://github.com/canc3s/wechat-versions/releases) |

下载并安装（聊天记录保留，仅替换 `.app`）：

```bash
bash scripts/wechat-download.sh --build=269077
# 或 fallback：bash scripts/wechat-download.sh --fallback
```

---

## 推荐安装方式

### 日常推荐：Framework 稳定模式

```bash
git clone https://github.com/zheyangdezhanghao/wxyyds.git
cd wxyyds
bash install.sh --with-framework --yes
```

你将获得：

| 功能 | 实现方式 | 状态 |
|------|----------|------|
| 防撤回 | 静态 Patch RecallGuard | ✅ 稳定 |
| 多开 | 静态 Patch MultiGate | ✅ 稳定 |
| 禁更新 | WXYydsHook FreezeLock | ✅ 稳定 |
| 菜单栏 | WXYydsHook MenuBar | ✅ |
| 撤回提醒 | WXYydsHook RecallNotify | 默认关，菜单开启 |
| 退群监控 / 系统浏览器 | ExitWatch / OpenLink | 默认关，菜单开启 |

稳定模式下 **不启用** 聊天内灰字指针 Hook，避免登录后闪退。

### 最简模式：仅 Patch

```bash
bash install.sh --yes
```

或直接用上游 WeChatTweak：

```bash
brew install tanranv5/tap/wechattweak
wechattweak patch
open -n /Applications/WeChat.app
```

---

## 实验功能：聊天内灰字

SovietExtension 风格的「对方撤回了一条消息」灰色系统提示，在 269077 上通过指针 Hook 实现，**尚未稳定**。

```bash
WXYYDS_RECALL_INCHAT=1 bash install.sh --with-framework --yes
```

| 项目 | 说明 |
|------|------|
| RE 偏移 | `offsets/hook_269077.json` → `hookPointerSlotVA: 0x94D5750` |
| 源码 | `WXYydsHook/Modules/WXRevokeInChat.mm` |
| 已知问题 | 登录后 10–20 秒可能闪退；启动可能卡顿 |
| 建议 | 开发者验证用；普通用户请用稳定模式 |

恢复稳定模式（重新安装，不带环境变量）：

```bash
bash install.sh --with-framework --yes
```

并确认 `~/.wxyyds/config.json`：

```json
{
  "modules": {
    "recallInChat": false,
    "recallNotify": false
  }
}
```

---

## 安装后验证

```bash
# 二进制 Patch 检查
bash scripts/smoke-stability.sh

# Framework 日志（稳定模式示例）
tail -f /tmp/wxyyds-hook.log
# 期望：WXYydsHook v0.6.1
# 期望：RevokeInChat: module disabled

# Patch 字节验证（稳定模式）
python3 tools/patcher.py /Applications/WeChat.app offsets/config.json 269077 x86_64 verify
```

稳定模式 Patch 期望：

| 标识 | 地址 (VA) | 期望机器码 |
|------|-----------|------------|
| revoke | `4F4D4C0` | `B801000000C3` |
| multiInstance | `247B08` | `909090909090` |

---

## 模块配置

Framework 模块开关保存在 `~/.wxyyds/config.json`。也可通过菜单 **wxyyds 助手** 切换。

默认配置（稳定、低卡顿）：

| 模块 | 默认值 |
|------|--------|
| freezeLock | ✅ 开 |
| menuBar | ✅ 开 |
| recallNotify | ❌ 关 |
| recallInChat | ❌ 关 |
| exitWatch | ❌ 关 |
| openLink | ❌ 关 |

部分功能修改后需**完全退出并重启微信**。

---

## 故障排除

| 现象 | 处理 |
|------|------|
| 登录后自动退出 | 检查是否用过 `WXYYDS_RECALL_INCHAT=1`；改回稳定模式重装 |
| 启动很卡 | 确认 `recallNotify: false`；或改用 `--patch-only` |
| Patch 验证失败 | 微信版本不是 269077：`bash install.sh --check-only` |
| 菜单没有出现 | Framework 未注入：确认 `Rely/Plugin/WXYyds.framework` 存在，重跑 `bash WXYydsHook/build.sh` |
| 想恢复原版微信 | `bash uninstall.sh` 或从 `backups/` 手动还原 |

---

## 相关文档

- [GUIDE.md](GUIDE.md) — 完整使用指南
- [ROADMAP.md](ROADMAP.md) — 功能路线图
- [CONTRIBUTING.md](../CONTRIBUTING.md) — 贡献新 build offsets
