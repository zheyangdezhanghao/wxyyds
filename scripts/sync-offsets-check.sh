#!/bin/bash
# CI 检查：本地 offsets 是否与 WeChatTweak 上游一致

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "sync-offsets-check (CI)"
if bash "$ROOT/scripts/sync-offsets.sh"; then
    echo "PASS: offsets in sync with upstream"
    exit 0
fi
rc=$?
if [ "$rc" -eq 2 ]; then
    echo "FAIL: local offsets/config.json differs from WeChatTweak upstream"
    echo "Run: bash scripts/sync-offsets.sh --apply"
    exit 1
fi
exit "$rc"
