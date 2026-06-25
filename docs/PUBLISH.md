# 发布到 GitHub

本机未检测到 `gh` CLI，请按以下步骤手动发布。

## 1. 在 GitHub 创建仓库

访问 https://github.com/new

- Repository name: `wxyyds`
- Public
- 不要勾选「Add README」（本地已有）

## 2. 推送代码

```bash
cd /Volumes/DATA/wxyyds

git add -A
git commit -m "$(cat <<'EOF'
feat: wxyyds v0.1.0 — 极客微信助手首版

- 统一 install.sh 安全模式（默认不替换微信、不碰聊天数据）
- Intel x86_64 + Apple Silicon arm64 双架构 patch
- 合并 tanranv5 offsets（含 build 269077）
- canc3s/wechat-versions 集成下载与 SHA256 校验
- Python patcher + wxyyds CLI
EOF
)"

git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/wxyyds.git
git push -u origin main
```

## 3. 创建首个 Release

```bash
# 安装 gh 后
brew install gh
gh auth login

gh release create v0.1.0 \
  --title "wxyyds v0.1.0 — 一个极客的理想之地" \
  --notes "$(cat <<'EOF'
## wxyyds v0.1.0

**一个极客的理想之地** — macOS 微信增强助手

### 功能
- RecallGuard 防撤回
- MultiGate 多开
- FreezeLock 禁更新（arm64 部分版本）
- 安全安装：默认不替换微信、不触碰聊天数据

### Intel 快速安装
\`\`\`bash
git clone https://github.com/YOUR_USERNAME/wxyyds.git
cd wxyyds
bash install.sh
\`\`\`

### 致谢
- SovietExtension / WeChatTweak / tanranv5 / canc3s/wechat-versions
EOF
)"
```

## 4. 替换远程 URL

将 `YOUR_USERNAME` 换成你的 GitHub 用户名。
