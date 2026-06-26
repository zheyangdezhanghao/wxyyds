# Apple Silicon (M 系列) 用户指南

适用于 **arm64** Mac（M1 / M2 / M3 / M4）。

## 一键安装

```bash
# 方式 1：一行命令
curl -fsSL https://raw.githubusercontent.com/zheyangdezhanghao/wxyyds/main/scripts/bootstrap.sh | bash

# 方式 2：双击
# 下载项目后双击「一键安装.command」

# 方式 3：手动
git clone https://github.com/zheyangdezhanghao/wxyyds.git
cd wxyyds
bash install.sh
```

安装前请 **完全退出微信**。脚本可自动帮你退出。

## 支持的功能

| 功能 | Patch 模式（默认） | Framework 模式 |
|------|-------------------|----------------|
| 防撤回 RecallGuard | ✅ | ✅ |
| 多开 MultiGate | ✅ | ✅ |
| 禁自动更新 FreezeLock | ⚠️ 部分版本 | ✅ `--with-freeze` |
| 退群监控 ExitWatch | ❌ | ✅ 需 Framework |
| 系统浏览器 OpenLink | ❌ | ✅ 需 Framework |

**小白推荐**：直接 `bash install.sh`（Patch 模式，最稳）。

Framework 模式：`bash install.sh --with-freeze`（需 `Rely/insert_dylib`，可通过 `scripts/build-framework.sh` 获取）。

## 推荐微信版本

manifest 中 Apple Silicon fallback：

- build **32288**（4.1.5.28）— 当前已验证 arm64 offsets（防撤回 + 多开）
- 若版本不支持，安装脚本会 **交互式提示升级**（聊天记录保留）

查看全部支持版本：

```bash
./tools/wxyyds versions
```

## 权限

**系统设置 → 隐私与安全性 → 完整磁盘访问权限** → 给终端 / Cursor 开启。

## 验证安装

```bash
bash scripts/smoke-stability.sh

# 含启动存活测试（15 秒）
WXYYDS_SMOKE_LAUNCH=1 bash scripts/smoke-stability.sh
```

## 全平台静态测试（开发/CI）

```bash
bash scripts/test-all.sh      # offsets + 编译 + 安全审计
bash scripts/audit-secrets.sh # 推送前密钥扫描
```

## 卸载

```bash
bash uninstall.sh
```

## 与 Intel 的区别

| | Apple Silicon | Intel |
|---|---------------|-------|
| 默认模式 | Patch | Patch |
| Framework | 可选全功能 | 仅 FreezeLock |
| 最新测试 build | 32288 (4.1.5.28) | 269077 (4.1.11) |

> **说明**：无 M 系列 Mac 时，在 Intel 上运行 `bash scripts/test-arm64-sim.sh` 可下载真实 DMG 并对 arm64 slice 做 patch + verify。CI（macos-latest）也会自动跑此测试。
