# wxyyds 路线图

## 短期 ✅ 进行中

| 模块 | 代号 | Intel 269077 | Apple Silicon 32288 | 说明 |
|------|------|--------------|----------------------|------|
| 防撤回 | RecallGuard | ✅ 静态 Patch | ✅ Patch | 原消息保留 |
| 多开 | MultiGate | ✅ Patch | ✅ Patch | `open -n` |
| **禁更新** | **FreezeLock** | ✅ Framework | ✅ Framework | Sparkle Swizzle，默认开 |
| **菜单栏** | **MenuBar** | ✅ Framework | ✅ Framework | wxyyds 助手 |
| **撤回提醒** | **RecallNotify** | ⚠️ Framework（默认关） | ⚠️ Framework | 弹窗 + 系统通知 |
| **聊天内灰字** | **RecallInChat** | 🧪 实验 | 🔜 | 269077 指针 Hook，不稳定 |

### Intel 269077 安装模式

| 模式 | 命令 | 状态 |
|------|------|------|
| Patch-only | `bash install.sh` | ✅ 生产可用 |
| Framework 稳定 | `bash install.sh --with-framework` | ✅ 推荐 |
| Framework 灰字 | `WXYYDS_RECALL_INCHAT=1 bash install.sh --with-framework` | 🧪 实验 |

## 中期 🔧

| 模块 | 代号 | 依赖 |
|------|------|------|
| 聊天内灰字（稳定） | RecallInChat | call-site Hook 或安全 intercept |
| 撤回同步手机 | RecallSync | Framework |
| 退群提醒 | ExitWatch | Framework（已有，默认关） |
| 系统浏览器 | OpenLink | Framework（已有，默认关） |
| 消息时间戳 | TimeStamp+ | Framework |
| 聊天记录导出 | ChatExport | Framework |
| Apple Silicon 4.1.11 | arm64 offsets | 社区 RE |

## 后期 📋

| 模块 | 代号 |
|------|------|
| 好友状态检测 | GhostCheck |
| 群关键词提醒 | KeywordAlert |
| 免打扰群折叠 | FoldPro |
| 消息转发规则 | AutoForward |
| 隐藏正在输入 | StealthType |

## 验证清单

### Patch-only / 稳定 Framework

1. 完全退出微信后重开
2. 让好友发消息并撤回 → **原消息仍保留**
3. `bash scripts/smoke-stability.sh` 全部 ✅

### Framework 功能

1. 菜单栏出现 **wxyyds 助手**
2. 开启「撤回提醒」后重启微信
3. 好友撤回 → 弹窗 + 系统通知（原消息仍保留）
4. 日志：`tail -f /tmp/wxyyds-hook.log`

### 实验灰字（开发者）

1. `WXYYDS_RECALL_INCHAT=1 bash install.sh --with-framework`
2. 登录后观察是否闪退
3. `bash scripts/test-recall-inchat.sh`
