#!/bin/bash
# wxyyds — 微信版本下载器
# 集成 canc3s/wechat-versions 自动下载、SHA256 校验、安装

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$ROOT_DIR/offsets/manifest.json"
APP_PATH="${WXYYDS_APP:-/Applications/WeChat.app}"
CANC3S_API="https://api.github.com/repos/canc3s/wechat-versions/releases"
CANC3S_DL="https://github.com/canc3s/wechat-versions/releases/download"
TMP_DIR="${TMPDIR:-/tmp}/wxyyds-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}👉 [INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}✅ [OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️  [WARN]${NC} $*"; }
die()   { echo -e "${RED}❌ [ERROR]${NC} $*" >&2; exit 1; }

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT
mkdir -p "$TMP_DIR"

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        arm64|aarch64) echo "arm64" ;;
        x86_64|i386)   echo "x86_64" ;;
        *) die "Unsupported architecture: $arch" ;;
    esac
}

read_build() {
    if [ ! -d "$APP_PATH" ]; then
        echo ""
        return
    fi
    defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo ""
}

# 从 manifest.json 读取 fallback 配置
get_fallback() {
    local arch="$1"
    python3 -c "
import json, sys
with open('$MANIFEST') as f:
    m = json.load(f)
fb = m.get('fallback', {}).get('$arch', {})
print(fb.get('canc3s_tag',''))
print(fb.get('dmg',''))
print(fb.get('build',''))
"
}

# 根据 build 号查 manifest
lookup_by_build() {
    local build="$1"
    python3 -c "
import json
with open('$MANIFEST') as f:
    m = json.load(f)
for v in m.get('versions', []):
    if v.get('build') == '$build':
        print(v.get('canc3s_tag',''))
        print(v.get('dmg',''))
        sys.exit(0)
" 2>/dev/null || true
}

download_and_verify() {
    local tag="$1"
    local dmg_name="$2"
    local dest="$TMP_DIR/$dmg_name"

    info "Downloading $dmg_name from canc3s/wechat-versions ($tag) ..."

    local url="$CANC3S_DL/$tag/$dmg_name"
    local sha_url="$url.sha256"

    if ! curl -fsSL -o "$dest" "$url"; then
        die "Download failed: $url"
    fi

    if curl -fsSL -o "$TMP_DIR/check.sha256" "$sha_url" 2>/dev/null; then
        local expected actual
        expected="$(awk '{print $1}' "$TMP_DIR/check.sha256")"
        if command -v shasum >/dev/null 2>&1; then
            actual="$(shasum -a 256 "$dest" | awk '{print $1}')"
        else
            actual="$(sha256sum "$dest" | awk '{print $1}')"
        fi
        if [ "$expected" != "$actual" ]; then
            die "SHA256 mismatch! expected=$expected actual=$actual"
        fi
        ok "SHA256 verified"
    else
        warn "No .sha256 file found, skipping checksum"
    fi

    echo "$dest"
}

install_dmg() {
    local dmg_path="$1"
    info "Mounting DMG ..."
    local mount_point
    mount_point="$(hdiutil attach "$dmg_path" -nobrowse -quiet | tail -1 | awk '{$1=$2=""; print $0}' | xargs)"
    if [ -z "$mount_point" ]; then
        die "Failed to mount DMG"
    fi

    local wechat_app
    wechat_app="$(find "$mount_point" -maxdepth 2 -name 'WeChat.app' -type d 2>/dev/null | head -1)"
    if [ -z "$wechat_app" ]; then
        hdiutil detach "$mount_point" -quiet 2>/dev/null || true
        die "WeChat.app not found in DMG"
    fi

    info "Installing to $APP_PATH ..."
    if [ -d "$APP_PATH" ]; then
        warn "Removing existing WeChat.app"
        rm -rf "$APP_PATH"
    fi
    cp -R "$wechat_app" "$APP_PATH"

    hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    ok "WeChat installed"
}

usage() {
    cat <<EOF
Usage: wechat-download.sh [options]

Options:
  --build=BUILD     Install specific build (lookup in manifest)
  --tag=TAG         canc3s release tag (e.g. v4.1.11.21-mac)
  --dmg=NAME        DMG filename
  --fallback        Install recommended version for current arch
  --app=PATH        WeChat.app destination (default: /Applications/WeChat.app)
  -h, --help        Show help

Examples:
  ./scripts/wechat-download.sh --fallback
  ./scripts/wechat-download.sh --tag=v4.1.10.53-mac --dmg=WeChatMac_4.1.10.53.dmg
EOF
}

main() {
    local mode=""
    local tag="" dmg="" build=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --fallback) mode="fallback"; shift ;;
            --build=*)  build="${1#*=}"; mode="build"; shift ;;
            --tag=*)    tag="${1#*=}"; shift ;;
            --dmg=*)    dmg="${1#*=}"; shift ;;
            --app=*)    APP_PATH="${1#*=}"; shift ;;
            -h|--help)  usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    local arch
    arch="$(detect_arch)"

    if [ "$mode" = "fallback" ] || [ -z "$mode" ]; then
        info "Using fallback for arch=$arch"
        local lines
        lines="$(get_fallback "$arch")"
        tag="$(echo "$lines" | sed -n '1p')"
        dmg="$(echo "$lines" | sed -n '2p')"
        build="$(echo "$lines" | sed -n '3p')"
    elif [ "$mode" = "build" ] && [ -n "$build" ]; then
        local lines
        lines="$(lookup_by_build "$build")"
        tag="$(echo "$lines" | sed -n '1p')"
        dmg="$(echo "$lines" | sed -n '2p')"
        if [ -z "$tag" ]; then
            lines="$(get_fallback "$arch")"
            tag="$(echo "$lines" | sed -n '1p')"
            dmg="$(echo "$lines" | sed -n '2p')"
            warn "Build $build not in manifest, using fallback"
        fi
    fi

    if [ -z "$tag" ] || [ -z "$dmg" ]; then
        die "Cannot resolve download target. Use --fallback or --tag/--dmg"
    fi

    local dmg_path
    dmg_path="$(download_and_verify "$tag" "$dmg")"
    install_dmg "$dmg_path"

    local new_build
    new_build="$(read_build)"
    ok "Installed WeChat build=$new_build"
}

main "$@"
