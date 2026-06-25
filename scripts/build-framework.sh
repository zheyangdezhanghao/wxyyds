#!/bin/bash
# 从 SovietExtension 构建 WXYyds.framework（仅 Apple Silicon / arm64）
# Intel Mac 用户无需运行此脚本

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
SRC_DIR="$BUILD_DIR/SovietExtension"
OUT_FRAMEWORK="$ROOT/Rely/Plugin/WXYyds.framework"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}👉${NC} $*"; }
ok()   { echo -e "${GREEN}✅${NC} $*"; }
die()  { echo -e "${RED}❌${NC} $*" >&2; exit 1; }

if [ "$(uname -m)" = "x86_64" ]; then
    echo "Intel Mac 检测到 — Framework 模式仅用于 Apple Silicon。"
    echo "Intel 用户使用 Binary Patch 即可（防撤回 + 多开），无需编译 Framework。"
    echo ""
    echo "若要为 CI/Release 交叉编译 arm64 Framework，加 --force 继续。"
    [ "${1:-}" = "--force" ] || exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    die "需要 Xcode 命令行工具: xcode-select --install"
fi

mkdir -p "$BUILD_DIR" "$ROOT/Rely/Plugin"

if [ ! -d "$SRC_DIR/.git" ]; then
    info "克隆 SovietExtension ..."
    git clone --depth 1 https://github.com/MustangYM/SovietExtension.git "$SRC_DIR"
fi

info "编译 SovietExtension.framework (arm64) ..."
PROJECT="$SRC_DIR/SovietExtension/SovietExtension.xcodeproj"
xcodebuild \
    -project "$PROJECT" \
    -scheme SovietExtension \
    -configuration Release \
    -arch arm64 \
    ONLY_ACTIVE_ARCH=NO \
    BUILD_DIR="$BUILD_DIR/xcode" \
    build

BUILT_FW="$(find "$BUILD_DIR/xcode" -name 'SovietExtension.framework' -type d | head -1)"
[ -n "$BUILT_FW" ] || die "编译失败，未找到 framework"

rm -rf "$OUT_FRAMEWORK"
cp -R "$BUILT_FW" "$OUT_FRAMEWORK"

# 重命名为 WXYyds
if [ -f "$OUT_FRAMEWORK/SovietExtension" ]; then
    mv "$OUT_FRAMEWORK/SovietExtension" "$OUT_FRAMEWORK/WXYyds"
fi
if [ -f "$OUT_FRAMEWORK/Versions/A/SovietExtension" ]; then
    mv "$OUT_FRAMEWORK/Versions/A/SovietExtension" "$OUT_FRAMEWORK/Versions/A/WXYyds"
fi

# 复制 insert_dylib
for tool in insert_dylib insert_dylib_arm64; do
    src="$SRC_DIR/SovietExtension/Rely/$tool"
    if [ -f "$src" ]; then
        cp "$src" "$ROOT/Rely/$tool"
        chmod +x "$ROOT/Rely/$tool"
        ok "Copied $tool"
    fi
done

ok "WXYyds.framework → $OUT_FRAMEWORK"
echo "Apple Silicon 用户运行: bash install.sh"
