#!/bin/bash
# Apple Silicon 模拟测试（无需 M 系列 Mac）
# 下载 arm64 微信 DMG → 自动匹配 offsets → patch → verify

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/offsets/config.json"
TMP="${TMPDIR:-/tmp}/wxyyds-arm64-sim-$$"
TEST_APP="$TMP/WeChat.app"
CANC3S_DL="https://github.com/canc3s/wechat-versions/releases/download"

ARM64_TEST_TAG="${WXYYDS_ARM64_TEST_TAG:-v4.1.5.28-mac}"
ARM64_TEST_DMG="${WXYYDS_ARM64_TEST_DMG:-WeChatMac-4.1.5.28.dmg}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${CYAN}👉 [arm64-sim]${NC} $*"; }
ok()   { echo -e "${GREEN}✅${NC} $*"; }
die()  { echo -e "${RED}❌${NC} $*" >&2; exit 1; }

cleanup() {
    hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true
    rm -rf "$TMP" 2>/dev/null || true
}
trap cleanup EXIT
mkdir -p "$TMP"

echo "wxyyds Apple Silicon 模拟测试"
echo "=============================="
echo "  测试机: $(uname -m)"
echo "  DMG: $ARM64_TEST_DMG"
echo ""

unset https_proxy http_proxy ALL_PROXY HTTPS_PROXY HTTP_PROXY 2>/dev/null || true

info "下载 DMG ..."
if ! curl -fsSL --retry 3 --retry-delay 5 -o "$TMP/$ARM64_TEST_DMG" "$CANC3S_DL/$ARM64_TEST_TAG/$ARM64_TEST_DMG"; then
    if [ -n "${WXYYDS_ARM64_DMG_CACHE:-}" ] && [ -f "${WXYYDS_ARM64_DMG_CACHE}" ]; then
        info "使用缓存 DMG: $WXYYDS_ARM64_DMG_CACHE"
        cp "${WXYYDS_ARM64_DMG_CACHE}" "$TMP/$ARM64_TEST_DMG"
    else
        die "下载失败（网络问题）。可设置 WXYYDS_ARM64_DMG_CACHE=/path/to.dmg 重试"
    fi
fi

info "挂载 WeChat.app ..."
mkdir -p "$TMP/mnt"
hdiutil attach "$TMP/$ARM64_TEST_DMG" -mountpoint "$TMP/mnt" -nobrowse -quiet
src="$(find "$TMP/mnt" -maxdepth 3 -name 'WeChat.app' -type d | head -1)"
[ -n "$src" ] || die "DMG 内未找到 WeChat.app"
cp -R "$src" "$TEST_APP"
hdiutil detach "$TMP/mnt" -quiet
rmdir "$TMP/mnt" 2>/dev/null || true

build="$(defaults read "$TEST_APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "")"
short="$(defaults read "$TEST_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")"
info "微信版本: $short build=$build"
file "$TEST_APP/Contents/MacOS/WeChat" | grep -qE 'arm64|universal' || die "无 arm64 slice"

info "自动匹配 arm64 offsets 并验证 patch ..."
MATCHED_BUILD="$(python3 << PY
import json, shutil, subprocess, sys, tempfile
from pathlib import Path

root = Path("$ROOT")
config = json.loads((root / "offsets/config.json").read_text())
app = Path("$TEST_APP")
builds = []
for v in config:
    b = v["version"]
    if any(e.get("arch") == "arm64" for t in v.get("targets", []) for e in t.get("entries", [])):
        builds.append(b)

# 优先实际 build，再试全部 arm64 build（从新到旧）
order = ["$build"] + sorted(set(builds), key=int, reverse=True)
order = [b for i, b in enumerate(order) if b and b not in order[:i]]

for cand in order:
    work = Path("$TMP") / f"try-{cand}"
    if work.exists():
        shutil.rmtree(work)
    shutil.copytree(app, work / "WeChat.app")
    r = subprocess.run(
        [sys.executable, str(root / "tools/patcher.py"), str(work / "WeChat.app"), str(root / "offsets/config.json"), cand, "arm64"],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        continue
    v = subprocess.run(
        [sys.executable, str(root / "tools/patcher.py"), str(work / "WeChat.app"), str(root / "offsets/config.json"), cand, "arm64", "verify"],
        capture_output=True, text=True,
    )
    if v.returncode == 0:
        print(cand)
        sys.exit(0)

print("NONE")
sys.exit(1)
PY
)" || die "无法为 build=$build 匹配任何 arm64 offsets"

ok "offsets 匹配成功: config build=$MATCHED_BUILD（DMG build=$build）"

if [ "$build" != "$MATCHED_BUILD" ]; then
    info "提示: canc3s DMG build ($build) 与 offsets build ($MATCHED_BUILD) 不同，但 patch 已验证通过"
fi

info "交叉编译 arm64 Framework ..."
WXYYDS_BUILD_ARCH=arm64 bash "$ROOT/WXYydsHook/build.sh" >/tmp/wxyyds-arm64-fw.log 2>&1
file "$ROOT/Rely/Plugin/WXYyds.framework/Versions/A/WXYyds" | grep -q arm64 || die "Framework 非 arm64"
ok "arm64 Framework OK"

python3 -c "
import json
m = json.load(open('$ROOT/offsets/manifest.json'))
fb = m.get('fallback', {}).get('arm64', {})
cfg_build = '$MATCHED_BUILD'
if fb.get('build') != cfg_build:
    print(f'  ⚠️  manifest fallback build={fb.get(\"build\")} 与实测可用 build={cfg_build} 不一致')
else:
    print(f'  ✅ manifest fallback 与实测 build 一致')
"

echo ""
echo "=============================="
ok "Apple Silicon 模拟测试全部通过"
echo "  可用 offsets build: $MATCHED_BUILD"
echo "  测试 DMG build:     $build"
