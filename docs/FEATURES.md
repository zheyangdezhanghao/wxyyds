# 顺手可加的好用功能

基于 SovietExtension / WeChatTweak 架构，以下功能实现成本较低、实用性强，适合作为 wxyyds 的 P1/P2 增强。

## 已纳入（P0）

| 功能 | 模块 | 实现方式 |
|------|------|----------|
| 防撤回 | RecallGuard | Binary Patch / Runtime Hook |
| 多开 | MultiGate | Binary Patch |
| 禁更新 | FreezeLock | Binary Patch (arm64) / Framework |
| 退群监控 | ExitWatch | Framework Hook |
| 系统浏览器 | OpenLink | Framework Inline Patch |

## 推荐顺手加入（P1，低成本高收益）

### 1. 消息时间戳增强
- **难度**: ★★☆
- **做法**: Hook `MessageWrap`，读取 offset +256 毫秒时间戳，在消息气泡旁显示
- **价值**: 群聊追溯、取证

### 2. Alfred / Raycast 快速搜索
- **难度**: ★★☆
- **做法**: 参考 [sunnyyoung 博客](https://blog.sunnyyoung.net/rang-wei-xin-macos-ke-hu-duan-zhi-chi-alfred/)，暴露搜索 API
- **价值**: 极客工作流标配

### 3. 免打扰群折叠优化
- **难度**: ★★☆
- **做法**: Hook 会话列表排序，自定义折叠规则
- **价值**: 群多时减少干扰

### 4. 复制消息纯文本快捷键
- **难度**: ★☆☆
- **做法**: 菜单项 + 调用已有复制逻辑，去除格式
- **价值**: 日常高频

### 5. 启动时检查 offsets 更新
- **难度**: ★☆☆
- **做法**: `wxyyds update` 已在 CLI 中实现，安装脚本可自动调用
- **价值**: 减少版本失效焦虑

## 可选模块（P2，默认关闭）

### 6. 禁止发送「正在输入」
- **难度**: ★★★
- **风险**: 中等（行为异常检测）
- **做法**: Hook typing indicator 发送函数

### 7. 撤回消息同步到手机（文件传输助手）
- **难度**: ★★★
- **需求**: Issue #980 社区呼声
- **做法**: 拦截撤回事件 → 转发内容到 FileHelper

### 8. 聊天记录导出
- **难度**: ★★★
- **做法**: Hook 数据库读取 + 导出 JSON/Markdown

### 9. RedRush 抢红包（默认关闭）
- **难度**: ★★★★★
- **风险**: 高（封号 + 合规）
- **做法**: 独立模块，需深度逆向红包消息链

### 10. GroupBot 群助手（默认关闭）
- **难度**: ★★★★
- **做法**: 关键词匹配 + 自动回复 Hook

## 不建议默认开启

- 自动通过好友请求
- 批量群发
- 任何涉及资金自动操作的默认开启功能

## 功能开关设计

所有 P2 功能通过 `~/.wxyyds/config.json` 控制，默认：

```json
{
  "modules": {
    "recallGuard": true,
    "multiGate": true,
    "freezeLock": true,
    "exitWatch": true,
    "openLink": false,
    "redRush": false,
    "groupBot": false
  }
}
```
