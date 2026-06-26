#!/bin/bash
# 从 tanranv5/WeChatTweak 同步 offsets/config.json

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$ROOT/offsets/config.json"
UPSTREAM_URL="${WXYYDS_UPSTREAM_CONFIG:-https://raw.githubusercontent.com/tanranv5/WeChatTweak/refs/heads/master/config.json}"
TMP="$(mktemp)"
APPLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1; shift ;;
        -h|--help)
            cat <<EOF
Usage: sync-offsets.sh [--apply]

  默认：对比本地 offsets/config.json 与 WeChatTweak 上游，显示差异摘要
  --apply：用上游覆盖本地 config.json（会先备份到 offsets/config.json.bak）

上游: $UPSTREAM_URL
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

unset https_proxy http_proxy ALL_PROXY HTTPS_PROXY HTTP_PROXY 2>/dev/null || true

echo "wxyyds sync-offsets"
echo "==================="
echo "  upstream: $UPSTREAM_URL"
echo "  local:    $LOCAL"
echo ""

if ! curl -fsSL --retry 3 -o "$TMP" "$UPSTREAM_URL"; then
    echo "ERROR: 无法下载上游 config.json" >&2
    exit 1
fi

if ! python3 -m json.tool "$TMP" >/dev/null 2>&1; then
    echo "ERROR: 上游 JSON 无效" >&2
    exit 1
fi

python3 << PY
import json, hashlib, sys
from pathlib import Path

local_path = Path("$LOCAL")
remote_path = Path("$TMP")

def norm(data):
    return json.dumps(data, sort_keys=True, separators=(",", ":"))

local = json.loads(local_path.read_text()) if local_path.exists() else []
remote = json.loads(remote_path.read_text())

lh = hashlib.sha256(norm(local).encode()).hexdigest()[:12]
rh = hashlib.sha256(norm(remote).encode()).hexdigest()[:12]

def builds(cfg, arch):
    out = set()
    for v in cfg:
        for t in v.get("targets", []):
            for e in t.get("entries", []):
                if e.get("arch") == arch:
                    out.add(v["version"])
    return sorted(out, key=int)

if lh == rh:
    print("  ✅ 本地 config 与上游一致 (hash %s)" % lh)
    sys.exit(0)

print("  ⚠️  本地与上游不同")
print("     local hash:  %s (%d versions)" % (lh, len(local)))
print("     remote hash: %s (%d versions)" % (rh, len(remote)))
print("")
print("  x86_64 builds  local: %s" % ", ".join(builds(local, "x86_64")[-3:] or ["(none)"]))
print("  x86_64 builds remote: %s" % ", ".join(builds(remote, "x86_64")[-3:] or ["(none)"]))
print("  arm64 builds   local: %s" % ", ".join(builds(local, "arm64")[-3:] or ["(none)"]))
print("  arm64 builds  remote: %s" % ", ".join(builds(remote, "arm64")[-3:] or ["(none)"]))
print("")
print("  运行 bash scripts/sync-offsets.sh --apply 以同步上游")
sys.exit(2)
PY
rc=$?

if [ "$rc" -eq 0 ]; then
    rm -f "$TMP"
    exit 0
fi

if [ "$rc" -eq 2 ] && [ "$APPLY" -eq 1 ]; then
    cp "$LOCAL" "$LOCAL.bak"
    cp "$TMP" "$LOCAL"
    python3 -m json.tool "$LOCAL" >/dev/null
    echo ""
    echo "  ✅ 已同步上游 config.json"
    echo "  📦 备份: offsets/config.json.bak"
    rm -f "$TMP"
    exit 0
fi

rm -f "$TMP"
exit "$rc"
