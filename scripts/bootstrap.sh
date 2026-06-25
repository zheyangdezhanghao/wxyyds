#!/bin/bash
# 一行命令安装 wxyyds：下载仓库并运行 install.sh
# 用法: curl -fsSL https://raw.githubusercontent.com/zheyangdezhanghao/wxyyds/main/scripts/bootstrap.sh | bash

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO="https://github.com/zheyangdezhanghao/wxyyds.git"
INSTALL_DIR="${WXYYDS_HOME:-$HOME/wxyyds}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}"
cat <<'BANNER'
 wxyyds 在线安装
 防撤回 · 多开 · 聊天记录安全
BANNER
echo -e "${NC}"

if ! command -v git >/dev/null 2>&1; then
    echo "❌ 未找到 git，请先安装 Xcode 命令行工具："
    echo "   xcode-select --install"
    exit 1
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "📂 已有安装目录: $INSTALL_DIR"
    echo "   正在更新 ..."
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "📥 正在下载 wxyyds ..."
    git clone "$REPO" "$INSTALL_DIR"
fi

echo ""
echo -e "${GREEN}🚀 开始安装 ...${NC}"
echo ""
cd "$INSTALL_DIR"
exec bash install.sh "$@"
