# Apple Silicon 用户指南

本文档面向 **Apple Silicon (arm64)** 用户。通用安装与 FAQ 见 **[GUIDE.md](GUIDE.md)**。

---

## 推荐版本

| 项目 | 值 |
|------|-----|
| 微信版本 | 4.1.5.28 |
| Build | **32288** |
| 二进制 | `Contents/MacOS/WeChat` |
| 状态 | ✅ Patch 已模拟验证 |

**4.1.11 (build 269077) 在 M 系列上不可用** — WeChatTweak 上游 offsets 仅含 x86_64 slice，无 arm64 条目。

---

## 安装

### Patch-only（默认，最稳）

```bash
git clone https://github.com/zheyangdezhanghao/wxyyds.git
cd wxyyds
bash install.sh --yes
```

### Framework 模式（菜单 + 禁更新）

```bash
bash install.sh --with-framework --yes
```

安装脚本会自动编译 WXYydsHook。32288 上防撤回仍靠静态 Patch。

---

## 从 4.1.11 降级

若已安装 Universal 版 4.1.11，运行 `bash install.sh` 会提示不支持并引导降级：

```bash
bash scripts/wechat-download.sh --fallback
bash install.sh --yes
```

**仅替换 `/Applications/WeChat.app`，聊天记录在 `~/Library/Containers/com.tencent.xinWeChat` 中完整保留。**

---

## 验证

```bash
bash scripts/smoke-stability.sh
WXYYDS_SMOKE_LAUNCH=1 bash scripts/smoke-stability.sh
```

---

## 与 Intel 的差异

| 项目 | Intel 269077 | Apple Silicon 32288 |
|------|--------------|---------------------|
| 最新微信 | ✅ 4.1.11 | ❌ 需用 4.1.5.28 |
| Framework | ✅ 完整支持 | ✅ Patch + Framework |
| 聊天内灰字 | 🧪 实验（269077） | 🔜 待 arm64 RE |
| 二进制路径 | `wechat.dylib` | `WeChat` 主二进制 |

---

## 相关文档

- [GUIDE.md](GUIDE.md) — 完整使用指南
- [CONTRIBUTING.md](../CONTRIBUTING.md) — 贡献 arm64 offsets（急需）
