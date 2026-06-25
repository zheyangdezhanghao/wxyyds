# Intel Mac 用户指南

你的环境：**x86_64 (Intel)**，微信 **4.1.7 (build 34817)**。

## 好消息：无需升级微信

build `34817` 已在 wxyyds offsets 中适配，支持：

- **RecallGuard** 防撤回
- **MultiGate** 多开

直接安装即可，**不会替换你的微信，不会动聊天记录**。

## 数据在哪里（wxyyds 永远不会碰）

| 路径 | 内容 | wxyyds 是否修改 |
|------|------|----------------|
| `~/Library/Containers/com.tencent.xinWeChat` | 聊天记录、数据库 | ❌ 永不 |
| `~/Library/Group Containers/group.com.tencent.xinWeChat` | 共享数据 | ❌ 永不 |
| `/Applications/WeChat.app` | 程序本体 | ✅ 仅 patch 二进制 |

## 一键安装（推荐，零数据风险）

```bash
cd /Volumes/DATA/wxyyds

# 1. 先完全退出微信
osascript -e 'quit app "WeChat"'

# 2. 安装插件（默认安全模式）
bash install.sh
```

安装前会自动：

1. 备份 `WeChat` 二进制到 `wxyyds/backups/wechat-34817-时间戳/`
2. 应用防撤回 + 多开 patch
3. 重签名

## 如果提示权限不足

到 **系统设置 → 隐私与安全性 → 完整磁盘访问权限**，给当前终端（Terminal / Cursor / iTerm）开启权限。

## 多开

```bash
open -n /Applications/WeChat.app
```

## 卸载插件（恢复原始二进制）

```bash
bash uninstall.sh
```

或从 `wxyyds/backups/` 手动恢复备份文件。

## 可选：升级到 4.1.11（聊天记录保留）

仅当你需要最新微信功能时才升级：

```bash
bash scripts/upgrade-wechat-safe.sh
```

此脚本会：

- 要求你确认
- 备份整个 `WeChat.app`
- 从 [canc3s/wechat-versions](https://github.com/canc3s/wechat-versions/releases) 下载 4.1.11
- **不删除** `~/Library/Containers/com.tencent.xinWeChat`
- 自动 patch 并安装插件

## Intel vs Apple Silicon

| 功能 | Intel (你的机器) | Apple Silicon |
|------|------------------|---------------|
| 防撤回 | ✅ Patch | ✅ Patch / Framework |
| 多开 | ✅ Patch | ✅ Patch / Framework |
| 禁更新 | ⚠️ 部分版本 | ✅ |
| 退群监控 | ❌ 需 Framework | ✅ Framework |
| 系统浏览器 | ❌ 需 Framework | ✅ Framework |

Intel 用户**不需要**编译 `WXYyds.framework`。

## 查看支持版本

```bash
./tools/wxyyds versions
```
