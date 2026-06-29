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
YES=0
CHECK_ONLY=0
BACKUP_DIR="${WXYYDS_BACKUP_DIR:-$ROOT_DIR/backups}"

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

ask_yes() {
    local prompt="$1" default="${2:-y}"
    if [ "$YES" -eq 1 ]; then
        return 0
    fi
    local hint="Y/n"
    [ "$default" = "n" ] && hint="y/N"
    read -r -p "$(echo -e "${CYAN}❓ ${prompt} [${hint}]${NC} ")" ans || true
    ans="${ans:-$default}"
    case "$ans" in
        y|Y|yes|YES|是) return 0 ;;
        *) return 1 ;;
    esac
}

pause_if_interactive() {
    if [ "$YES" -eq 0 ] && [ -t 0 ]; then
        echo ""
        read -r -p "> 按回车键继续..." _
    fi
}

check_dependencies() {
    info "检查运行环境 ..."
    if ! command -v python3 >/dev/null 2>&1; then
        die "未找到 python3。请先安装 Xcode 命令行工具：xcode-select --install"
    fi
    ok "python3 可用"
    if [ ! -f "$CONFIG" ]; then
        die "缺少 offsets 配置：$CONFIG（请完整 clone 仓库，不要只下载 install.sh）"
    fi
    ok "offsets 配置就绪"
}

prompt_full_disk_access() {
    echo ""
    echo -e "${YELLOW}💡 首次安装提示${NC}"
    echo "   若安装失败提示「权限不足」，请到："
    echo "   系统设置 → 隐私与安全性 → 完整磁盘访问权限"
    echo "   为「终端 / Cursor / iTerm」开启权限后重新运行安装。"
    echo ""
}

ensure_wechat_quit() {
    if ! pgrep -x WeChat >/dev/null 2>&1; then
        ok "微信未在运行"
        return 0
    fi
    warn "检测到微信正在运行（安装前需完全退出）"
    if ask_yes "是否帮你自动退出微信？" "y"; then
        osascript -e 'quit app "WeChat"' 2>/dev/null || true
        sleep 2
        if pgrep -x WeChat >/dev/null 2>&1; then
            warn "微信仍在运行，请手动退出后重试"
            die "安装已取消"
        fi
        ok "微信已退出"
    else
        die "请先完全退出微信，再重新运行：bash install.sh"
    fi
}

find_wechat_app() {
    local candidates=(
        "/Applications/WeChat.app"
        "$HOME/Applications/WeChat.app"
    )
    for p in "${candidates[@]}"; do
        if [ -d "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

handle_missing_wechat() {
    echo ""
    warn "未在 /Applications 找到 WeChat.app"
    if ask_yes "是否自动下载并安装已适配的微信版本？（聊天记录不会丢失）" "y"; then
        bash "$ROOT_DIR/scripts/wechat-download.sh" --fallback --app="$APP_PATH"
        read_versions
        ok "微信已安装"
        return 0
    fi
    die "请先安装微信，或指定路径：bash install.sh --app=/path/to/WeChat.app"
}

handle_unsupported_version() {
    local build="$1" arch="$2"
    echo ""
    if [ "$arch" = "arm64" ] && [ "$build" = "269077" ]; then
        warn "检测到 Apple Silicon + 微信 4.1.11 (build 269077)"
        echo ""
        echo "  原因：4.1.11 的 offsets 目前仅有 Intel (x86_64) 版本。"
        echo "  上游 WeChatTweak 也仅维护 x64，M 芯片无法 patch 此版本。"
        echo ""
        echo "  解决方案：降级到已验证的 4.1.5.28 (build 32288)"
        echo "  ✅ 仅替换 WeChat.app，聊天记录完全保留"
        echo "  ✅ 降级后支持：防撤回 + 多开"
        echo ""
    else
        warn "当前微信版本 build=${build} 尚未适配 ${arch}"
        echo ""
    fi
    echo "  你可以："
    echo "    1) 自动安装已适配版本（推荐，聊天记录保留）"
    echo "    2) 查看已支持版本列表"
    echo "    3) 退出，等待社区适配"
    echo ""
    if [ "$YES" -eq 1 ]; then
        UPGRADE_WECHAT=1
        bash "$ROOT_DIR/scripts/upgrade-wechat-safe.sh" --yes --app="$APP_PATH"
        read_versions
        return 0
    fi
    read -r -p "$(echo -e "${CYAN}请选择 [1/2/3]（默认 1）:${NC} ")" choice || true
    choice="${choice:-1}"
    case "$choice" in
        1)
            bash "$ROOT_DIR/scripts/upgrade-wechat-safe.sh" --app="$APP_PATH"
            read_versions
            ;;
        2)
            "$ROOT_DIR/tools/wxyyds" versions
            die "请升级微信或更换版本后重新安装"
            ;;
        *)
            die "已取消安装。你的微信未被修改。"
            ;;
    esac
}

post_install_success() {
    echo ""
    if [ -x "$ROOT_DIR/scripts/smoke-stability.sh" ]; then
        info "运行安装后检查 ..."
        bash "$ROOT_DIR/scripts/smoke-stability.sh" || warn "部分检查未通过，请查看上方提示"
    fi
    echo ""
    echo -e "${GREEN}==============================${NC}"
    echo -e "${GREEN}✅ wxyyds 安装成功！${NC}"
    echo -e "${GREEN}   防撤回 + 多开 已启用${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo ""
    echo "📱 启动微信:  open -a WeChat"
    echo "📱 多开一个:  open -n \"$APP_PATH\""
    echo "🗑️  卸载恢复:  bash \"$ROOT_DIR/uninstall.sh\""
    echo ""
    if ask_yes "是否现在打开微信？" "y"; then
        open -a "$APP_PATH" 2>/dev/null || open -a WeChat 2>/dev/null || true
    fi
}

run_check_only() {
    local arch="$1"
    read_versions
    echo ""
    info "检测模式（--check-only）：不会修改任何文件"
    echo ""
    echo "  本机架构:     $arch"
    echo "  微信路径:     $APP_PATH"
    echo "  微信版本:     ${APP_SHORT:-unknown} (build ${APP_BUILD:-unknown})"
    echo ""

    if [ ! -d "$APP_PATH" ]; then
        warn "未找到 WeChat.app"
        "$ROOT_DIR/tools/wxyyds" versions --app="$APP_PATH" 2>/dev/null || true
        exit 1
    fi

    if [ -z "$APP_BUILD" ]; then
        die "无法读取 CFBundleVersion"
    fi

    if is_build_supported "$APP_BUILD" "$arch"; then
        ok "当前版本 build=${APP_BUILD} 支持 ${arch}，可运行 bash install.sh 安装"
        exit 0
    fi

    if [ "$arch" = "arm64" ] && [ "$APP_BUILD" = "269077" ]; then
        warn "Apple Silicon 不支持 4.1.11 (269077)，需降级到 4.1.5.28 (32288)"
        echo "  聊天记录不会丢失。运行 bash install.sh 并按提示选择降级即可。"
    else
        warn "当前版本 build=${APP_BUILD} 不支持 ${arch}"
    fi
    "$ROOT_DIR/tools/wxyyds" versions --app="$APP_PATH"
    exit 1
}

usage() {
    cat <<EOF
Usage: install.sh [options]

小白推荐：直接双击「一键安装.command」，或在终端运行 bash install.sh

默认 Patch-only：防撤回 + 多开，不注入 Framework（最稳）。
Intel 269077 推荐：bash install.sh --with-framework（菜单 + 禁更新 + 稳定防撤回）。

Options:
  -y, --yes         全自动安装，跳过所有确认（适合脚本）
  --upgrade-wechat  从 canc3s 下载并安装新版本（仅替换 .app，聊天记录保留）
  --skip-download   不自动下载微信（默认开启）
  --with-freeze     注入 WXYydsHook Framework（菜单 + 禁更新 + 可选撤回提醒）
  --with-framework  同 --with-freeze
  --patch-only      仅 Binary Patch，不注入 Framework（默认，最稳）
  --check-only      仅检测版本是否支持，不 patch、不修改微信
  --force           跳过版本检查，强制 patch
  --app=PATH        WeChat.app 路径 (default: /Applications/WeChat.app)
  -h, --help        Show help

环境变量：
  WXYYDS_RECALL_INCHAT=1   实验：聊天内灰字（269077，可能登录后闪退，不推荐日常）
  WXYYDS_BACKUP_DIR        自定义 WeChat.app 备份目录

数据安全说明：
  聊天记录在 ~/Library/Containers/com.tencent.xinWeChat
  wxyyds 永远不会删除或修改该目录。
  仅会备份并修改 /Applications/WeChat.app 内二进制文件。

文档：docs/GUIDE.md · Intel：docs/INTEL-GUIDE.md

一行命令安装（复制到终端）：
  git clone https://github.com/zheyangdezhanghao/wxyyds.git && cd wxyyds && bash install.sh
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
      -y|--yes)          YES=1; shift ;;
      --check-only)      CHECK_ONLY=1; shift ;;
      --force)           FORCE=1; shift ;;
      --with-hook|--with-freeze|--with-framework) PATCH_ONLY=0; shift ;;
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

  check_dependencies
  prompt_full_disk_access

  local detected_app=""
  if detected_app="$(find_wechat_app)"; then
    APP_PATH="$detected_app"
    FRAMEWORK_DST="$APP_PATH/Contents/MacOS/${FRAMEWORK_NAME}.framework"
    info "找到微信: $APP_PATH"
  fi

  local arch
  arch="$(detect_arch)"

  if [ "$CHECK_ONLY" -eq 1 ]; then
    run_check_only "$arch"
  fi

  ensure_wechat_quit
  pause_if_interactive

  info "Host architecture: $arch"

  if [ "$arch" = "x86_64" ]; then
    if [ "$PATCH_ONLY" -eq 1 ]; then
      info "Intel 默认: 仅 Patch（防撤回 + 多开，最稳）"
    else
      info "Intel Framework 模式: 仅禁自动更新 + 多开 Patch（防撤回仍靠静态 Patch）"
    fi
  elif [ "$arch" = "arm64" ]; then
    info "Apple Silicon: 默认 Patch（防撤回 + 多开）"
    info "Framework 全功能（菜单+撤回提醒）: bash install.sh --with-framework"
  fi

  # 构建 Hook Framework（Intel 4.1.11）
  if [ ! -d "$FRAMEWORK_SRC" ] || [ ! -f "$FRAMEWORK_SRC/Versions/A/WXYyds" ]; then
    build_hook_framework || warn "WXYyds.framework 未编译，仅使用 Binary Patch 模式"
  fi

  if [ ! -d "$APP_PATH" ]; then
    handle_missing_wechat
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
      bash "$ROOT_DIR/scripts/upgrade-wechat-safe.sh" $([ "$YES" -eq 1 ] && echo --yes) --app="$APP_PATH"
      read_versions
      info "New build: $APP_BUILD"
    else
      handle_unsupported_version "$APP_BUILD" "$arch"
    fi
    if [ "$FORCE" -eq 0 ] && ! is_build_supported "$APP_BUILD" "$arch"; then
      die "当前版本 build=${APP_BUILD} 仍不支持，请查看: $ROOT_DIR/tools/wxyyds versions"
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
      echo "    WXYydsHook: 菜单 + 撤回提醒 + 聊天内灰字 + FreezeLock"
      inject_framework "$arch"
      local patch_ids=""
      if [ "$APP_BUILD" = "269077" ] && [ "$arch" = "x86_64" ]; then
        if [ "${WXYYDS_RECALL_INCHAT:-0}" = "1" ]; then
          patch_ids="multiInstance"
          echo "    防撤回: 指针 Hook + 聊天内灰字（实验性，可能不稳定）"
        else
          echo "    防撤回: 静态 Patch RecallGuard + MultiGate（稳定模式）"
        fi
      else
        echo "    防撤回: 静态 Patch（revoke + multiInstance）"
      fi
      if [ -n "$patch_ids" ]; then
        apply_patch "$arch" "$APP_BUILD" "$patch_ids"
      else
        apply_patch "$arch" "$APP_BUILD"
      fi
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
    if [ "$APP_BUILD" = "269077" ] && [ "$arch" = "x86_64" ] && [ "${WXYYDS_RECALL_INCHAT:-0}" = "1" ]; then
      WXYYDS_PATCH_IDS=multiInstance python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$APP_BUILD" "$arch" verify || die "Patch verification failed"
      ok "Patch verification passed (multiInstance + Framework 指针 Hook 灰字)"
    elif [ "$APP_BUILD" = "269077" ] && [ "$arch" = "x86_64" ]; then
      python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$APP_BUILD" "$arch" verify || die "Patch verification failed"
      ok "Patch verification passed (revoke + multiInstance + Framework 稳定模式)"
    else
      python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$APP_BUILD" "$arch" verify || die "Patch verification failed"
      ok "Patch verification passed (revoke + multiInstance + Framework)"
    fi
  else
    python3 "$ROOT_DIR/tools/patcher.py" "$APP_PATH" "$CONFIG" "$APP_BUILD" "$arch" verify || die "Patch verification failed"
    ok "Patch verification passed"
  fi

  post_install_success
}

main "$@"
