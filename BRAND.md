# wxyyds 品牌手册

> **一个极客的理想之地**

---

## 品牌核心

| 项目 | 内容 |
|------|------|
| **品牌名** | wxyyds |
| **全称** | WeChat eXtension — Your Dedicated Suite |
| **主 Slogan** | 一个极客的理想之地 |
| **英文 Slogan** | Where Geeks Take Control |
| **副 Slogan** | 微信，由你掌控 / Take Control of Your WeChat |
| **理念** | 开源、自由、极客精神 |
| **调性** | 克制、专业、不花哨、技术感 |

---

## 品牌故事（一句话）

微信本该是工具，不是牢笼。wxyyds 把控制权还给使用者——防撤回、多开、禁更新，一切由你决定。

---

## 功能模块命名

| 模块 | 代号 | 一句话描述 |
|------|------|-----------|
| 消息防撤回 | **RecallGuard** | 删不掉的记忆 |
| 客户端多开 | **MultiGate** | 一机多号，各行其道 |
| 阻止更新 | **FreezeLock** | 版本你做主 |
| 退群监控 | **ExitWatch** | 谁走了，一目了然 |
| 系统浏览器 | **OpenLink** | 链接不走弯路 |
| 自动抢红包 | **RedRush** | 手速的尽头是代码（默认关闭） |
| 群助手 | **GroupBot** | 你的群，你的规则（默认关闭） |

---

## 文案体系

### 安装成功

```
✅ wxyyds 已就位
   一个极客的理想之地，从现在开始。
```

### 版本不匹配

```
⚠️  当前微信版本尚未适配
   wxyyds 将为你安装最近支持的稳定版本。
   极客不等官方，但也不蛮干。
```

### 更新提示

```
🔄 wxyyds 有新版本
   运行 wxyyds update 即可更新插件，无需重装微信。
```

### 卸载

```
👋 wxyyds 已卸载
   微信已恢复原状。随时欢迎回来。
```

### CLI 帮助页眉

```
wxyyds — 一个极客的理想之地
WeChat macOS Assistant for Hackers
```

---

## 色彩规范

| 角色 | 色值 | 用途 |
|------|------|------|
| 主色 | `#07C160` | 微信绿衍生，品牌识别 |
| 强调色 | `#1A1A2E` | 深色背景、终端输出 |
| 辅助色 | `#E94560` | 警告、重要提示 |
| 文字色 | `#F5F5F5` | 深色模式主文字 |
| 次要文字 | `#8892B0` | 说明、注释 |

---

## Logo 概念

```
  ╔═══════════════════════════╗
  ║                           ║
  ║   ██╗    ██╗██╗  ██╗     ║
  ║   ██║    ██║╚██╗██╔╝     ║
  ║   ██║ █╗ ██║ ╚███╔╝      ║
  ║   ██║███╗██║ ██╔██╗      ║
  ║   ╚███╔███╔╝██╔╝ ██╗     ║
  ║    ╚══╝╚══╝ ╚═╝  ╚═╝     ║
  ║         yyds              ║
  ║                           ║
  ║  一个极客的理想之地        ║
  ╚═══════════════════════════╝
```

ASCII Logo 用于终端安装脚本输出。正式 Logo 见 `assets/logo.svg`。

---

## 徽章 (Shields)

```markdown
![platform](https://img.shields.io/badge/platform-macOS-1A1A2E?style=flat-square)
![arch](https://img.shields.io/badge/arch-Universal%20(arm64%20%2B%20x86__64)-07C160?style=flat-square)
![wechat](https://img.shields.io/badge/WeChat-4.0%2B-07C160?style=flat-square)
![license](https://img.shields.io/badge/license-AGPL--3.0-blue?style=flat-square)
```

---

## 命名规范

| 场景 | 规范 | 示例 |
|------|------|------|
| 项目/仓库 | 小写 | `wxyyds` |
| CLI 命令 | 小写 | `wxyyds install` |
| Framework | PascalCase | `WXYyds.framework` |
| 菜单名 | 中文 | `wxyyds 助手` |
| 环境变量 | 大写前缀 | `WXYYDS_HOME` |
| 配置文件 | 小写 | `config.json` |

---

## 禁止事项

- 不使用「破解」「外挂」「破解版」等词汇，统一用「助手」「增强」「Tweak」
- 不做商业化收费
- 不默认开启高风险功能（抢红包、群机器人）
- README 必须包含免责声明

---

## 致谢语（固定格式）

```
## Thanks

wxyyds 站在巨人的肩膀上：

- [SovietExtension](https://github.com/MustangYM/SovietExtension) — 插件架构灵感
- [WeChatTweak](https://github.com/sunnyyoung/WeChatTweak) — 二进制 Patch 引擎
- [tanranv5/WeChatTweak](https://github.com/tanranv5/WeChatTweak) — 持续维护的 offsets
- [wechat-versions](https://github.com/canc3s/wechat-versions) — 微信版本归档

For Geeks. For Freedom.
```
