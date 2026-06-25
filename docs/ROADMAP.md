# wxyyds 路线图

## 短期 ✅ 进行中

| 模块 | 代号 | Intel 4.1.11 | 说明 |
|------|------|--------------|------|
| 防撤回 | RecallGuard | ✅ Patch/Hook | 原消息保留 |
| **撤回提醒** | **RecallNotify** | ✅ Hook | 弹窗+系统通知，提示哪条被撤回 |
| 多开 | MultiGate | ✅ Patch | `open -n` |
| **禁更新** | **FreezeLock** | ✅ Runtime Swizzle | Sparkle 方法拦截 |

## 中期 🔧

| 模块 | 代号 | 依赖 |
|------|------|------|
| 撤回同步手机 | RecallSync | Intel Framework 完整 Hook |
| 退群提醒 | ExitWatch | Framework |
| 系统浏览器 | OpenLink | Framework |
| 消息时间戳 | TimeStamp+ | Framework |
| 聊天记录导出 | ChatExport | Framework |

## 后期 📋

| 模块 | 代号 |
|------|------|
| 好友状态检测 | GhostCheck |
| 群关键词提醒 | KeywordAlert |
| 免打扰群折叠 | FoldPro |
| 消息转发规则 | AutoForward |
| 隐藏正在输入 | StealthType |

## 验证 RecallNotify

1. 完全退出微信后重开
2. 让好友发消息并撤回
3. 应看到：**弹窗** + **系统通知** + **原消息仍保留**

日志：`tail -f /tmp/wxyyds-hook.log`
