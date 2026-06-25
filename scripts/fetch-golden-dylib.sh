#!/bin/bash
# 下载未修改的 wechat.dylib 到 Rely/golden/（用于撤回标记 trampoline）
set -euo pipefail
if [ -z "${BASH_VERSION:-}" ]; then exec /bin/bash "$0" "$@"; fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Rely/golden/wechat-269077-x86_64.dylib"
TMP="${TMPDIR:-/tmp}/wxyyds-golden-$$"
mkdir -p "$ROOT/Rely/golden" "$TMP"
trap 'rm -rf "$TMP"' EXIT

TAG="v4.1.11.21-mac"
DMG="WeChatMac_4.1.11.dmg"
URL="https://github.com/canc3s/wechat-versions/releases/download/${TAG}/${DMG}"

echo "Downloading $DMG ..."
curl -fsSL --http1.1 -o "$TMP/$DMG" "$URL" || curl -fsSL -o "$TMP/$DMG" "$URL"

MP="$(hdiutil attach "$TMP/$DMG" -nobrowse -quiet | tail -1 | awk '{$1=$2=""; print $0}' | xargs)"
APP="$(find "$MP" -maxdepth 2 -name 'WeChat.app' -type d | head -1)"
cp "$APP/Contents/Resources/wechat.dylib" "$OUT"
hdiutil detach "$MP" -quiet 2>/dev/null || true

python3 -c "
from pathlib import Path
b = Path('$OUT').read_bytes()[0x4000+0x4F4D4C0:0x4000+0x4F4D4C0+6]
print('revoke prologue:', b.hex())
assert b[0] == 0x55, 'unexpected prologue'
"
echo "Saved: $OUT"
