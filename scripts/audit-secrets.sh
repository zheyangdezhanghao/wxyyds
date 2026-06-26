#!/bin/bash
# 发布前安全审计：扫描密钥、临时文件、不应提交的内容

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

red()  { echo "  ❌ $*"; FAIL=$((FAIL + 1)); }
ok()   { echo "  ✅ $*"; }
warn() { echo "  ⚠️  $*"; }

echo "wxyyds security audit"
echo "====================="

echo ""
echo "[Git 跟踪文件中的密钥模式]"
if git -C "$ROOT" ls-files -z | xargs -0 grep -lE 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' 2>/dev/null; then
    red "发现 GitHub Token 模式（已跟踪文件）"
else
    ok "已跟踪文件无 GitHub Token"
fi

echo ""
echo "[工作区敏感文件]"
for f in docs/1111 .github-token .env backups; do
    if [ -e "$ROOT/$f" ]; then
        if git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            red "$f 已被 Git 跟踪（必须移除）"
        else
            ok "$f 存在但未跟踪（正确）"
        fi
    fi
done

echo ""
echo "[RE 临时产物]"
if git -C "$ROOT" ls-files | grep -E '^\.[^/]+\.txt$' >/dev/null 2>&1; then
    red "根目录 .*.txt 分析文件被跟踪"
else
    ok "无 RE 临时 .txt 被跟踪"
fi

echo ""
echo "[Git 历史 Token 扫描]"
if git -C "$ROOT" log --all -p 2>/dev/null | grep -qE 'ghp_[A-Za-z0-9]{20,}'; then
    red "Git 历史含 ghp_ token，需 rotate 并清理历史"
else
    ok "Git 历史无 ghp_ token"
fi

echo ""
echo "[不应公开的本地路径]"
LEAK_FILES=""
LEAK_FILES="$(git -C "$ROOT" ls-files | grep -v '^scripts/audit-secrets\.sh$' | xargs grep -lE '/Volumes/DATA/|/Users/[^/]+/\.cursor/projects/' 2>/dev/null || true)"
if [ -n "$LEAK_FILES" ]; then
    echo "$LEAK_FILES" | head -5
    red "已跟踪文件含本地路径，请移除后再推送"
else
    ok "无本地磁盘路径或 Cursor 项目路径硬编码"
fi

echo ""
echo "[个人邮箱/主机名模式（抽样）]"
if git -C "$ROOT" ls-files | xargs grep -lE '@kahndeiMac|kahn@' 2>/dev/null | head -1; then
    warn "部分文件含个人主机标识（建议改用通用示例）"
else
    ok "无常见个人主机标识"
fi

echo ""
echo "====================="
if [ "$FAIL" -gt 0 ]; then
    echo "AUDIT FAIL: $FAIL"
    exit 1
fi
echo "AUDIT PASS"
