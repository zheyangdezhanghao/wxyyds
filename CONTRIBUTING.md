# 贡献 offsets

wxyyds 的版本适配依赖社区贡献。每个新微信版本的适配通常需要 **1-3 天**逆向工作。

## 你需要提供什么

针对新的 `CFBundleVersion`（Build 号），在 `offsets/config.json` 中提交：

```json
{
  "version": "269077",
  "targets": [
    {
      "identifier": "revoke",
      "entries": [
        { "arch": "x86_64", "addr": "4F4D4C0", "asm": "B801000000C3" }
      ],
      "binary": "Contents/Resources/wechat.dylib"
    },
    {
      "identifier": "multiInstance",
      "entries": [
        { "arch": "x86_64", "addr": "247B08", "asm": "909090909090" }
      ],
      "binary": "Contents/Resources/wechat.dylib"
    }
  ]
}
```

同时在 `offsets/manifest.json` 中添加版本元数据（display 版本、canc3s tag、dmg 文件名）。

## 如何定位偏移

1. 从 [canc3s/wechat-versions](https://github.com/canc3s/wechat-versions/releases) 下载对应版本 DMG
2. 用 IDA / Hopper 打开 `wechat.dylib`（路径见下方）
3. 参考 [sunnyyoung 的博客](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-lan-jie-che-hui-gong-neng-shi-jian/) 定位撤回函数
4. 多开：搜索 `runningApplicationsWithBundleIdentifier` 相关逻辑
5. 禁更新：搜索 Sparkle / updater 相关符号

### wechat.dylib 路径（因版本而异）

| 版本范围 | 路径 |
|----------|------|
| 较新 4.1.x | `Contents/Resources/wechat.dylib` |
| 部分 4.1.8.x | `Contents/Frameworks/wechat.dylib` |
| 早期 4.x | `Contents/MacOS/WeChat` |

## PR 检查清单

- [ ] 已在对应架构真机验证（防撤回 + 多开）
- [ ] `addr` 为十六进制 VA（不含 `0x` 前缀）
- [ ] `asm` 为对应架构的机器码 hex
- [ ] `binary` 字段正确（如非默认 `Contents/MacOS/WeChat`）
- [ ] 更新了 `manifest.json`
- [ ] PR 标题格式：`offsets: add build XXXXX (arch)`

## 参考仓库

- [tanranv5/WeChatTweak config.json](https://github.com/tanranv5/WeChatTweak/blob/master/config.json) — 最新维护的 offsets
- [MustangYM/SovietExtension](https://github.com/MustangYM/SovietExtension) — Framework Hook 参考

## 自动化提醒

`.github/workflows/check-wechat-version.yml` 会监控 canc3s 新发布并自动创建 Issue，提醒社区适配。
