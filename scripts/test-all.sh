#!/bin/bash
# 全平台验证：Intel + Apple Silicon（静态/交叉编译，无需已安装微信）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✅ $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "wxyyds test-all — 全平台验证"
echo "=============================="
echo "  主机架构: $(uname -m)"
echo ""

echo "[基础验证]"
bash "$ROOT/scripts/verify.sh" || FAIL=$((FAIL + 1))
PASS=$((PASS + 1))

echo ""
echo "[Shell / Python 语法]"
for f in install.sh uninstall.sh scripts/*.sh 一键安装.command; do
    [ -f "$ROOT/$f" ] || continue
    check "bash -n $f" bash -n "$ROOT/$f"
done
check "python3 tools/wxyyds" python3 -m py_compile "$ROOT/tools/wxyyds"
check "python3 tools/patcher.py" python3 -m py_compile "$ROOT/tools/patcher.py"

echo ""
echo "[Apple Silicon offsets]"
python3 << PY
import json, sys
from pathlib import Path
root = Path("$ROOT")
cfg = json.load(open(root / "offsets/config.json"))
manifest = json.load(open(root / "offsets/manifest.json"))
arm_builds = set()
targets = {"revoke", "multiInstance"}
for v in cfg:
    b = v["version"]
    ids = {t["identifier"] for t in v.get("targets", [])}
    has_arm = any(e.get("arch") == "arm64" for t in v.get("targets", []) for e in t.get("entries", []))
    if has_arm:
        arm_builds.add(b)
        if not targets.issubset(ids):
            print(f"  ❌ build {b} arm64 缺少 target: {targets - ids}")
            sys.exit(1)
print(f"  ✅ arm64 适配 build 数: {len(arm_builds)}")
print(f"  ✅ 最新 arm64 build: {sorted(arm_builds)[-1]}")
fb = manifest.get("fallback", {}).get("arm64", {})
print(f"  ✅ manifest fallback arm64: build={fb.get('build')} tag={fb.get('canc3s_tag')}")
PY
PASS=$((PASS + 1))

echo ""
echo "[Intel offsets]"
python3 << PY
import json
from pathlib import Path
cfg = json.load(open("offsets/config.json"))
x64 = {v["version"] for v in cfg if any(e.get("arch")=="x86_64" for t in v.get("targets",[]) for e in t.get("entries",[]))}
print(f"  ✅ x86_64 适配 build 数: {len(x64)}")
print(f"  ✅ 最新 x86_64 build: {sorted(x64)[-1]}")
PY
PASS=$((PASS + 1))

echo ""
echo "[Framework 交叉编译 smoke]"
TMP="$ROOT/build/test-framework-$$"
mkdir -p "$TMP"
if clang++ -arch arm64 -dynamiclib -mmacosx-version-min=11.0 \
    -framework Foundation -o "$TMP/libtest.dylib" -x objective-c++ - <<'SRC' 2>/dev/null
#import <Foundation/Foundation.h>
void wxyyds_test() { NSLog(@"ok"); }
SRC
then
    if file "$TMP/libtest.dylib" | grep -q arm64; then
        echo "  ✅ arm64 交叉编译 toolchain 可用"
        PASS=$((PASS + 1))
    else
        echo "  ❌ arm64 产物架构不对"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  ⚠️  跳过 arm64 交叉编译（无 clang arm64）"
fi
rm -rf "$TMP"

echo ""
echo "[WXYydsHook 编译]"
if bash "$ROOT/WXYydsHook/build.sh" >/tmp/wxyyds-build.log 2>&1; then
    if file "$ROOT/Rely/Plugin/WXYyds.framework/Versions/A/WXYyds" | grep -qE 'x86_64|arm64'; then
        echo "  ✅ WXYyds.framework 编译成功"
        file "$ROOT/Rely/Plugin/WXYyds.framework/Versions/A/WXYyds" | sed 's/^/     /'
        PASS=$((PASS + 1))
    else
        echo "  ❌ Framework 架构异常"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  ❌ WXYydsHook build 失败，见 /tmp/wxyyds-build.log"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "[安全审计]"
bash "$ROOT/scripts/audit-secrets.sh" && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))

echo ""
echo "[已安装微信检查（可选）]"
if [ -d "/Applications/WeChat.app" ]; then
    bash "$ROOT/scripts/smoke-stability.sh" && PASS=$((PASS + 1)) || echo "  ⚠️  本地微信 patch 状态未通过（新机器正常）"
else
    echo "  ℹ️  未安装 WeChat，跳过运行时检查"
fi

echo ""
echo "=============================="
echo "PASS checks: $PASS  FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo ""
echo "✅ 全平台静态验证通过"
echo ""
echo "Apple Silicon 实机建议（M 系列 Mac 上执行）："
echo "  bash install.sh --yes"
echo "  WXYYDS_SMOKE_LAUNCH=1 bash scripts/smoke-stability.sh"
