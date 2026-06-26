#!/bin/bash
# 安装项目 git hooks（pre-push → audit-secrets.sh）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
git -C "$ROOT" config core.hooksPath .githooks
chmod +x "$ROOT/.githooks/pre-push" "$ROOT/scripts/audit-secrets.sh"
echo "✅ Git hooks 已安装: core.hooksPath=.githooks"
echo "   pre-push → scripts/audit-secrets.sh"
