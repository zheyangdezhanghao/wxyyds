# WXYyds.framework

Apple Silicon 全功能插件（基于 [SovietExtension](https://github.com/MustangYM/SovietExtension) 架构）。

## 当前状态

Framework **尚未预编译**。安装脚本会自动降级为 **Binary Patch 模式**（防撤回 + 多开 + 禁更新），功能仍然可用。

## 编译 Framework（可选，获取全功能）

```bash
# 1. 克隆 SovietExtension 作为参考实现
git clone https://github.com/MustangYM/SovietExtension.git /tmp/SovietExtension

# 2. 将 WXYyds/ 源码用 Xcode 编译为 WXYyds.framework
#    （WXYyds/ 目录将在后续版本提供完整源码）

# 3. 复制产物到此处
cp -R build/Release/WXYyds.framework ./Rely/Plugin/

# 4. 复制 insert_dylib
cp /tmp/SovietExtension/SovietExtension/Rely/insert_dylib ../insert_dylib
chmod +x ../insert_dylib

# 5. 重新运行安装
bash ../../install.sh
```

## Framework 模式额外功能

| 模块 | 功能 |
|------|------|
| ExitWatch | 退群监控 |
| OpenLink | 系统浏览器打开链接 |
| 菜单 UI | wxyyds 助手菜单栏 |

## insert_dylib

从 [SovietExtension/Rely](https://github.com/MustangYM/SovietExtension/tree/main/SovietExtension/Rely) 获取：

- `insert_dylib` (universal，推荐)
- `insert_dylib_arm64`
- `insert_dylib_x86_64`

放置于 `Rely/` 目录并 `chmod +x`。
