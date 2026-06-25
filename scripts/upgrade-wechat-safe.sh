#!/bin/bash
# 安全升级微信 — 仅替换 WeChat.app，不触碰聊天数据
# 聊天记录位于 ~/Library/Containers/com.tencent.xinWeChat

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="${WXYYDS_APP:-/Applications/WeChat.app}"
DATA_DIR="$HOME/Library/Containers/com.tencent.xinWeChat"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}👉 [INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}✅ [OK]${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️  [WARN]${NC} $*"; }
die()  { echo -e "${RED}❌ [ERROR]${NC} $*" >&2; exit 1; }

detect_arch() {
    case "$(uname -m)" in
        arm64) echo "arm64" ;;
        *)     echo "x86_64" ;;
    esac
}

usage() {
    cat <<EOF
Usage: upgrade-wechat-safe.sh [options]

安全升级微信到 wxyyds 已适配的最新版本。

保证：
  ✅ 不删除 ~/Library/Containers/com.tencent.xinWeChat（聊天记录）
  ✅ 不删除 ~/Library/Group Containers/group.com.tencent.xinWeChat
  ✅ 升级前备份当前 WeChat.app 到 wxyyds/backups/
  ✅ 仅替换 /Applications/WeChat.app

Options:
  --yes             跳过确认提示
  --app=PATH        目标路径
  -h, --help
EOF
}

main() {
    local auto_yes=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes)    auto_yes=1; shift ;;
            --app=*)  APP_PATH="${1#*=}"; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown: $1" ;;
        esac
    done

    local arch
    arch="$(detect_arch)"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  wxyyds 安全升级微信${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [ -d "$DATA_DIR" ]; then
        local data_size
        data_size="$(du -sh "$DATA_DIR" 2>/dev/null | awk '{print $1}')"
        ok "检测到聊天数据目录: $DATA_DIR ($data_size)"
        ok "此目录不会被修改或删除"
    else
        warn "未检测到聊天数据目录（可能是全新安装）"
    fi

    if [ -d "$APP_PATH" ]; then
        local cur_short cur_build
        cur_short="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")"
        cur_build="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "?")"
        info "当前微信: $cur_short (build $cur_build)"
    fi

    local target_build target_tag target_dmg
    target_build="$(python3 -c "
import json
with open('$ROOT_DIR/offsets/manifest.json') as f:
    m=json.load(f)
print(m['fallback']['$arch']['build'])
")"
    target_tag="$(python3 -c "
import json
with open('$ROOT_DIR/offsets/manifest.json') as f:
    m=json.load(f)
print(m['fallback']['$arch']['canc3s_tag'])
")"
    target_dmg="$(python3 -c "
import json
with open('$ROOT_DIR/offsets/manifest.json') as f:
    m=json.load(f)
print(m['fallback']['$arch']['dmg'])
")"

    info "目标版本: build $target_build ($target_tag)"

    echo ""
    warn "将执行以下操作："
    echo "  1. 备份当前 WeChat.app → $ROOT_DIR/backups/WeChat.app.bak"
    echo "  2. 从 canc3s/wechat-versions 下载 $target_dmg"
    echo "  3. SHA256 校验后安装到 $APP_PATH"
    echo "  4. 运行 wxyyds patch"
    echo ""
    echo "  ❌ 不会触碰: $DATA_DIR"
    echo ""

    if [ "$auto_yes" -eq 0 ]; then
        read -r -p "确认继续？[y/N] " ans
        case "$ans" in
            y|Y|yes|YES) ;;
            *) echo "已取消"; exit 0 ;;
        esac
    fi

    # 先退出微信
    if pgrep -x WeChat >/dev/null 2>&1; then
        info "正在退出微信 ..."
        osascript -e 'quit app "WeChat"' 2>/dev/null || true
        sleep 2
    fi

    # 备份当前 .app
    if [ -d "$APP_PATH" ]; then
        mkdir -p "$ROOT_DIR/backups"
        local bak="$ROOT_DIR/backups/WeChat.app.pre-upgrade.$(date +%Y%m%d-%H%M%S)"
        info "备份 WeChat.app → $bak"
        cp -R "$APP_PATH" "$bak"
        ok "备份完成"
    fi

    # 下载安装
    bash "$ROOT_DIR/scripts/wechat-download.sh" --tag="$target_tag" --dmg="$target_dmg" --app="$APP_PATH"

    # 安装插件
    bash "$ROOT_DIR/install.sh" --skip-download

    echo ""
    ok "升级完成！请重新登录微信（聊天记录应自动恢复）"
    echo "  open -a WeChat"
}

main "$@"
