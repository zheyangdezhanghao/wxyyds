#!/bin/bash
# wxyyds 卸载脚本 — 移除 Framework 并恢复干净二进制

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
APP_PATH="${WXYYDS_APP:-/Applications/WeChat.app}"
FRAMEWORK_NAME="WXYyds"
FRAMEWORK_DST="$APP_PATH/Contents/MacOS/${FRAMEWORK_NAME}.framework"
BINARY="$APP_PATH/Contents/MacOS/WeChat"
BACKUP="${BINARY}.wxyyds.bak"
DYLIB="$APP_PATH/Contents/Resources/wechat.dylib"
BACKUP_DIR="$ROOT_DIR/backups"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${CYAN}👉 [INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}✅ [OK]${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️  [WARN]${NC} $*"; }

if [ ! -d "$APP_PATH" ]; then
    warn "WeChat.app not found at $APP_PATH"
    exit 0
fi

info "Removing ${FRAMEWORK_NAME}.framework ..."
rm -rf "$FRAMEWORK_DST" 2>/dev/null || true

if [ -f "$BACKUP" ]; then
    info "Restoring original WeChat binary from backup ..."
    mv "$BACKUP" "$BINARY"
    ok "Binary restored"
else
    warn "No backup found at $BACKUP"
    warn "Framework injection may still be present in WeChat binary."
fi

if [ -f "$DYLIB" ]; then
    info "Restoring clean wechat.dylib ..."
    restored=0
    for golden in "$ROOT_DIR"/Rely/golden/wechat-*-x86_64.dylib; do
        [ -f "$golden" ] || continue
        cp "$golden" "$DYLIB"
        ok "wechat.dylib restored from $(basename "$golden")"
        restored=1
        break
    done

    if [ "$restored" -eq 0 ]; then
        for dir in $(ls -td "$BACKUP_DIR"/wechat-* 2>/dev/null); do
            candidate="$dir/Contents_Resources_wechat.dylib"
            [ -f "$candidate" ] || continue
            first="$(python3 -c "print(open('$candidate','rb').read()[0x4000+0x4F4D4C0:0x4000+0x4F4D4C0+1].hex())" 2>/dev/null || echo "")"
            if [ "$first" = "55" ]; then
                cp "$candidate" "$DYLIB"
                ok "wechat.dylib restored from backup $(basename "$dir")"
                restored=1
                break
            fi
        done
    fi

    if [ "$restored" -eq 0 ]; then
        info "Trying in-place revert of revoke static patch ..."
        if python3 -c "
from pathlib import Path
p = Path('$DYLIB')
data = bytearray(p.read_bytes())
off = 0x4000 + 0x4F4D4C0
patch = bytes.fromhex('b801000000c3')
orig = bytes.fromhex('554889e54157')
if data[off:off+6] == patch:
    data[off:off+6] = orig
    p.write_bytes(data)
    print('reverted')
elif data[off:off+1] == b'\\x55':
    print('already_clean')
else:
    raise SystemExit(1)
" 2>/dev/null; then
            ok "wechat.dylib revoke site reverted"
            restored=1
        fi
    fi

    if [ "$restored" -eq 0 ]; then
        warn "Could not restore clean wechat.dylib automatically"
        warn "Run: bash $ROOT_DIR/scripts/fetch-golden-dylib.sh"
    fi

    codesign -f -s - "$DYLIB" 2>/dev/null || true
fi

info "Re-signing ..."
codesign --remove-sign "$APP_PATH" 2>/dev/null || true
codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true

echo ""
echo -e "${GREEN}👋 wxyyds 已卸载${NC}"
echo -e "${GREEN}   Framework 已移除，dylib 已尽量恢复干净。${NC}"
echo -e "${CYAN}   重新安装稳定版: bash install.sh --patch-only --force${NC}"
