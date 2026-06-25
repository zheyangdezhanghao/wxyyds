#!/bin/bash
# 双击运行：wxyyds 傻瓜式一键安装（macOS）

cd "$(dirname "$0")"
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

clear
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║     wxyyds 一键安装（防撤回 + 多开）   ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  安装过程约 1 分钟，请勿关闭此窗口。"
echo ""

/bin/bash install.sh
EXIT=$?

echo ""
if [ "$EXIT" -eq 0 ]; then
    echo "  ✅ 全部完成。"
else
    echo "  ❌ 安装未完成（退出码 $EXIT）。请查看上方红色错误提示。"
fi
echo ""
read -r -p "按回车键关闭窗口..." _

exit "$EXIT"
