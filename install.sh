#!/bin/bash
# wxyyds 一键安装脚本
# 一个极客的理想之地

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
export WXYYDS_HOME="$ROOT_DIR"

APP_PATH="${WXYYDS_APP:-/Applications/WeChat.app}"
FRAMEWORK_NAME="WXYyds"
FRAMEWORK_SRC="$ROOT_DIR/Rely/Plugin/${FRAMEWORK_NAME}.framework"
FRAMEWORK_DST="$APP_PATH/Contents/MacOS/${FRAMEWORK_NAME}.framework"
INSERT_DYLIB="$ROOT_DIR/Rely/insert_dylib"
LOAD_DYLIB="@executable_path/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}"
SUPPORTED_FILE="$ROOT_DIR/Rely/supported_versions.txt"
CONFIG="$ROOT_DIR/offsets/config.json"
FORCE=0
SKIP_DOWNLOAD=1
UPGRADE_WECHAT=0
PATCH_ONLY=1
BACKUP_DIR="$ROOT_DIR/backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}"
    cat <<'BANNER'
 ██╗    ██╗██╗  ██╗██╗   ██╗██╗   ██╗██████╗ ███████╗
 ██║    ██║╚██╗██╔╝╚██╗ ██╔╝██║   ██║██╔══██╗██╔════╝
 ██║ █╗ ██║ ╚███╔╝  ╚████╔╝ ██║   ██║██║  ██║███████╗
 ██║███╗██║ ██╔██╗   ╚██╔╝  ██║   ██║██║  ██║╚════██║
 ╚███╔███╔╝██╔╝ ██╗   ██║   ╚██████╔╝██████╔╝███████║
  ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═════╝ ╚══════╝
          一个极客的理想之地 · Where Geeks Take Control
BANNER
    echo -e "${NC}"
}

info()  { echo -e "${CYAN}👉 [INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}✅ [OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️  [WARN]${NC} $*"; }
die()   { echo -e "${RED}❌ [ERROR]${NC} $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: install.sh [options]

默认安全模式：不替换微信、不触碰聊天数据目录，仅对 WeChat.app 打补丁。

Options:
  --upgrade-wechat  从 canc3s 下载并安装新版本（仅替换 .app，聊天记录保留）
  --skip-download   不自动下载微信（默认开启）
  --with-freeze     注入 Framework（仅禁自动更新，不含撤回 Hook）
  --patch-only      仅 Binary Patch，不注入 Framework（默认，最稳）
  --force           跳过版本检查，强制 patch
  --app=PATH        WeChat.app 路径 (default: /Applications/WeChat.app)
  -h, --help        Show help

数据安全说明：
  聊天记录在 ~/Library/Containers/com.tencent.xinWeChat
  wxyyds 永远不会删除或修改该目录。
  仅会备份并修改 /Applications/WeChat.app 内二进制文件。

Intel 用户当前版本 4.1.7 (34817) 已支持，直接运行：
  bash install.sh
EOF
}

detect_arch() {
    case "$(uname -m)" in
        arm64|aarch64) echo "arm64" ;;
        x86_64)        echo "x86_64" ;;
        *) die "Unsupported arch: $(uname -m)" ;;
    esac
}

read_versions() {
    if [ ! -d "$APP_PATH" ]; then
        APP_SHORT=""
        APP_BUILD=""
        return
    fi
    APP_SHORT="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")"
    APP_BUILD="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "")"
}

is_build_supported() {
    local build="$1" arch="$2"
    python3 -c "
import json
build='$build'
arch='$arch'
with open('$CONFIG') as f:
    configs = json.load(f)
for cfg in configs:
    if cfg.get('version') != build:
        continue
    for t in cfg.get('targets', []):
        for e in t.get('entries', []):
            if e.get('arch') == arch:
                exit(0)
exit(1)
"
}

is_framework_supported() {
    local build="$1"
    if [ ! -f "$SUPPORTED_FILE" ]; then
        return 1
    fi
    if grep -v '^#' "$SUPPORTED_FILE" | grep -v '^$' | awk -F'|' -v b="$build" '$3==b || $3=="*"{found=1} END{exit !found}'; then
        return 0
    fi
    return 1
}

pick_insert_dylib() {
    local arch="$1"
    if [ -x "$ROOT_DIR/Rely/insert_dylib" ]; then
        INSERT_DYLIB="$ROOT_DIR/Rely/insert_dylib"
    elif [ "$arch" = "arm64" ] && [ -x "$ROOT_DIR/Rely/insert_dylib_arm64" ]; then
        INSERT_DYLIB="$ROOT_DIR/Rely/insert_dylib_arm64"
    elif [ "$arch" = "x86_64" ] && [ -x "$ROOT_DIR/Rely/insert_dylib_x86_64" ]; then
        INSERT_DYLIB="$ROOT_DIR/Rely/insert_dylib_x86_64"
    else
        INSERT_DYLIB=""
    fi
}

inject_framework() {
    local arch="$1"
    if [ ! -d "$FRAMEWORK_SRC" ]; then
        warn "Framework not found at $FRAMEWORK_SRC — skipping injection (patch-only mode)"
        return 0
    fi

    pick_insert_dylib "$arch"
    if [ -z "$INSERT_DYLIB" ] || [ ! -x "$INSERT_DYLIB" ]; then
        warn "insert_dylib not found — skipping framework injection"
        warn "Place insert_dylib in Rely/ or build from SovietExtension"
        return 0
    fi

    local binary="$APP_PATH/Contents/MacOS/WeChat"
    if [ ! -f "$binary" ]; then
        die "WeChat binary not found: $binary"
    fi

    info "Injecting ${FRAMEWORK_NAME}.framework ..."
    rm -rf "$FRAMEWORK_DST"
    cp -R "$FRAMEWORK_SRC" "$FRAMEWORK_DST"

    if otool -L "$binary" 2>/dev/null | grep -q "$FRAMEWORK_NAME"; then
        ok "Framework already injected"
    else
        cp "$binary" "${binary}.wxyyds.bak"
        "$INSERT_DYLIB" --all-yes --no-strip-codesig "$LOAD_DYLIB" "$binary" "${binary}.tmp"
        mv "${binary}.tmp" "$binary"
        ok "Framework injected"
    fi
}

build_hook_framework() {
    if [ ! -f "$ROOT_DIR/WXYydsHook/build.sh" ]; then
        return 1
    fi
    info "Building WXYyds.framework (RecallNotify + FreezeLock) ..."
    bash "$ROOT_DIR/WXYydsHook/build.sh" || return 1
    ok "WXYyds.framework built"
}

restore_clean_dylib() {
    local dylib="$APP_PATH/Contents/Resources/wechat.dylib"
    local build="${APP_BUILD:-}"
    local golden="$ROOT_DIR/Rely/golden/wechat-${build}-x86_64.dylib"

    if [ -f "$golden" ]; then
        info "Restoring clean wechat.dylib from golden: $golden"
        cp "$golden" "$dylib"
        ok "wechat.dylib restored from golden (revoke hook ready)"
        return 0
    fi

    local candidate=""
    for dir in $(ls -td "$BACKUP_DIR"/wechat-* 2>/dev/null); do
        local f="$dir/Contents_Resources_wechat.dylib"
        [ -f "$f" ] || continue
        local first
        first="$(python3 -c "print(open('$f','rb').read()[0x4000+0x4F4D4C0:0x4000+0x4F4D4C0+1].hex())")"
        if [ "$first" = "55" ]; then
            candidate="$f"
            break
        fi
    done

    if [ -n "$candidate" ]; then
        info "Restoring clean wechat.dylib from backup: $candidate"
        cp "$candidate" "$dylib"
        ok "wechat.dylib restored (unpatched revoke site)"
        return 0
    fi

    warn "No clean wechat.dylib found (golden or backup with 0x55 prologue)"
    info "Trying to revert revoke static patch in-place ..."
    if python3 -c "
from pathlib import Path
p = Path('$dylib')
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
    print('unknown')
    raise SystemExit(1)
"; then
        ok "wechat.dylib revoke site reverted to original prologue"
        return 0
    fi
    warn "请运行: bash scripts/fetch-golden-dylib.sh"
    return 1
}

apply_patch() {
    local arch="$1" build="$2"
    local patch_ids="${3:-}"
    mkdir -p "$BACKUP_DIR"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local backup_sub="$BACKUP_DIR/wechat-${build}-${ts}"
    mkdir -p "$backup_sub"

    info "Backing up binaries to $backup_sub (可据此恢复) ..."
    python3 -c "
import json
from pathlib import Path
import shutil
app = Path('$APP_PATH')
config = json.load(open('$CONFIG'))
build = '$build'
arch = '$arch'
for cfg in config:
    if cfg.get('version') != build:
        continue
    binaries = set()
    for t in cfg.get('targets', []):
        for e in t.get('entries', []):
            if e.get('arch') == arch:
                binaries.add(t.get('binary', 'Contents/MacOS/WeChat'))
    for rel in binaries:
        src = app / rel
        if src.exists():
            dst = Path('$backup_sub') / rel.replace('/', '_')
            shutil.copy2(src, dst)
            print(f'  backed up: {rel}')
"

    info "Applying binary patches ..."
    if [ -n "$patch_ids" ]; then
        info "Patch targets: $patch_ids"
        WXYYDS_PATCH_IDS="$patch_ids" python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$build" "$arch"
    else
        python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$build" "$arch"
    fi
    ok "Backup saved: $backup_sub"
}

resign_app() {
    info "Re-signing WeChat.app ..."
    local dylib="$APP_PATH/Contents/Resources/wechat.dylib"
    if [ -f "$dylib" ]; then
        codesign -f -s - "$dylib" 2>/dev/null || warn "dylib codesign failed"
    fi
    codesign --remove-sign "$APP_PATH" 2>/dev/null || true
    codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || warn "codesign failed (may still work)"
    xattr -cr "$APP_PATH" 2>/dev/null || true
    ok "Re-signed"
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --force)           FORCE=1; shift ;;
      --with-hook|--with-freeze) PATCH_ONLY=0; shift ;;
      --patch-only)      PATCH_ONLY=1; shift ;;
      --skip-download)   SKIP_DOWNLOAD=1; shift ;;
      --upgrade-wechat)  UPGRADE_WECHAT=1; SKIP_DOWNLOAD=0; shift ;;
      --app=*)           APP_PATH="${1#*=}"; FRAMEWORK_DST="$APP_PATH/Contents/MacOS/${FRAMEWORK_NAME}.framework"; shift ;;
      -h|--help)         usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  banner

  echo -e "${GREEN}🔒 数据安全承诺${NC}"
  echo "   聊天记录目录: ~/Library/Containers/com.tencent.xinWeChat"
  echo "   wxyyds 不会删除或修改该目录，仅 patch WeChat.app 内二进制。"
  echo ""

  local arch
  arch="$(detect_arch)"
  info "Host architecture: $arch"

  if [ "$arch" = "x86_64" ]; then
    if [ "$PATCH_ONLY" -eq 1 ]; then
      info "Intel 默认: 仅 Patch（防撤回 + 多开，最稳）"
    else
      info "Intel Framework 模式: 仅禁自动更新 + 多开 Patch（防撤回仍靠静态 Patch）"
    fi
  fi

  # 构建 Hook Framework（Intel 4.1.11）
  if [ ! -d "$FRAMEWORK_SRC" ] || [ ! -f "$FRAMEWORK_SRC/Versions/A/WXYyds" ]; then
    build_hook_framework || warn "WXYyds.framework 未编译，仅使用 Binary Patch 模式"
  fi

  if [ ! -d "$APP_PATH" ]; then
    warn "WeChat.app not found at $APP_PATH"
    if [ "$SKIP_DOWNLOAD" -eq 0 ]; then
      warn "wxyyds 将为你安装最近支持的稳定版本"
      warn "极客不等官方，但也不蛮干。"
      bash "$ROOT_DIR/scripts/wechat-download.sh" --fallback --app="$APP_PATH"
    else
      die "WeChat.app not found. Open WeChat once or run without --skip-download"
    fi
  fi

  read_versions
  info "Detected WeChat:"
  echo "    CFBundleShortVersionString: ${APP_SHORT:-unknown}"
  echo "    CFBundleVersion (build):    ${APP_BUILD:-unknown}"

  if [ -z "$APP_BUILD" ]; then
    die "Cannot read CFBundleVersion"
  fi

  if ! is_build_supported "$APP_BUILD" "$arch"; then
    if [ "$FORCE" -eq 1 ]; then
      warn "Version $APP_BUILD not in offsets DB — force mode, continuing anyway"
    elif [ "$UPGRADE_WECHAT" -eq 1 ]; then
      echo ""
      warn "当前微信版本 $APP_BUILD 尚未适配"
      warn "将安装最近支持的版本（仅替换 WeChat.app，聊天记录保留）"
      bash "$ROOT_DIR/scripts/upgrade-wechat-safe.sh" --app="$APP_PATH"
      read_versions
      info "New build: $APP_BUILD"
    else
      echo ""
      die "Version $APP_BUILD not supported on $arch.

可选方案：
  1) 保持现有微信，等待社区适配 offsets（推荐，零风险）
  2) 升级到已适配版本（聊天记录保留）：
       bash scripts/upgrade-wechat-safe.sh
  3) 查看已支持版本：
       ./tools/wxyyds versions"
    fi
  else
    ok "Version $APP_BUILD supported for $arch"
  fi

  echo ""
  info "Install mode:"
  local use_hook=0
  if [ "$PATCH_ONLY" -eq 0 ] && [ -d "$FRAMEWORK_SRC" ] && [ -f "$ROOT_DIR/Rely/insert_dylib" ]; then
    if is_framework_supported "$APP_BUILD" || [ "$APP_BUILD" = "269077" ]; then
      use_hook=1
      echo "    WXYydsHook: FreezeLock（禁自动更新）"
      echo "    防撤回: 静态 Patch（revoke + multiInstance）"
      inject_framework "$arch"
      apply_patch "$arch" "$APP_BUILD"
    fi
  fi
  if [ "$use_hook" -eq 0 ]; then
    if [ "$PATCH_ONLY" -eq 1 ]; then
      echo "    Patch-only: RecallGuard + MultiGate (+ FreezeLock if offsets exist)"
    fi
    apply_patch "$arch" "$APP_BUILD"
  fi

  resign_app

  echo ""
  info "Post-install verification ..."
  if [ "$use_hook" -eq 1 ]; then
    python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$APP_BUILD" "$arch" verify || die "Patch verification failed"
    ok "Patch verification passed (revoke + multiInstance + Framework FreezeLock)"
  else
    python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$APP_BUILD" "$arch" verify || die "Patch verification failed"
    ok "Patch verification passed"
  fi

  echo ""
  echo -e "${GREEN}==============================${NC}"
  echo -e "${GREEN}✅ wxyyds 已就位${NC}"
  echo -e "${GREEN}   一个极客的理想之地，从现在开始。${NC}"
  echo -e "${GREEN}==============================${NC}"
  echo ""
  echo "启动微信:"
  echo "  open -a WeChat"
  echo ""
  echo "多开:"
  echo "  open -n $APP_PATH"
  echo ""
  echo "查看版本支持:"
  echo "  $ROOT_DIR/tools/wxyyds versions"
  echo ""
  echo "更新 offsets:"
  echo "  $ROOT_DIR/tools/wxyyds update"
  echo ""
  echo "卸载:"
  echo "  bash $ROOT_DIR/uninstall.sh"
}

main "$@"
