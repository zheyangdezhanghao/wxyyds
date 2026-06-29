# WXYyds.framework

Apple Silicon / Intel 全功能插件，源码位于仓库 **`WXYydsHook/`**（v0.6.1）。

## 编译

安装脚本会在需要时自动调用 `WXYydsHook/build.sh`。也可手动编译：

```bash
bash WXYydsHook/build.sh
```

产物输出到 `Rely/Plugin/WXYyds.framework`。

## 安装

```bash
# Intel 269077 推荐（稳定模式）
bash install.sh --with-framework --yes

# 仅 Patch，不注入 Framework
bash install.sh --patch-only --yes
```

需要 `Rely/insert_dylib`（仓库已包含，需 `chmod +x`）。

## Framework 模块

| 模块 | 功能 | 默认 |
|------|------|------|
| FreezeLock | 阻止 Sparkle 自动更新 | ✅ 开 |
| MenuBar | wxyyds 助手菜单 | ✅ 开 |
| RecallNotify | 撤回弹窗 + 系统通知 | ❌ 关 |
| RecallInChat | 聊天内灰色系统消息 | ❌ 关（实验：`WXYYDS_RECALL_INCHAT=1`） |
| ExitWatch | 退群监控 | ❌ 关 |
| OpenLink | 系统浏览器打开链接 | ❌ 关 |

配置：`~/.wxyyds/config.json`

## 支持版本

见 `Rely/supported_versions.txt`：

- **269077** — Intel x86_64，Patch + Framework
- **32288** — Apple Silicon arm64，Patch + Framework

## insert_dylib

来自 [SovietExtension/Rely](https://github.com/MustangYM/SovietExtension/tree/main/SovietExtension/Rely)，放置于 `Rely/` 目录。
