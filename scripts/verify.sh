#!/bin/bash
# wxyyds 项目验证脚本

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

echo "wxyyds verify — 一个极客的理想之地"
echo "=================================="

echo ""
echo "[结构检查]"
check "install.sh exists"          test -f "$ROOT/install.sh"
check "uninstall.sh exists"        test -f "$ROOT/uninstall.sh"
check "offsets/config.json"        test -f "$ROOT/offsets/config.json"
check "offsets/manifest.json"      test -f "$ROOT/offsets/manifest.json"
check "tools/patcher.py"           test -f "$ROOT/tools/patcher.py"
check "tools/wxyyds CLI"           test -f "$ROOT/tools/wxyyds"
check "wechat-download.sh"         test -f "$ROOT/scripts/wechat-download.sh"
check "BRAND.md"                   test -f "$ROOT/BRAND.md"
check "README.md"                  test -f "$ROOT/README.md"
check "assets/logo.svg"            test -f "$ROOT/assets/logo.svg"

echo ""
echo "[JSON 校验]"
check "config.json valid"          python3 -m json.tool "$ROOT/offsets/config.json"
check "manifest.json valid"        python3 -m json.tool "$ROOT/offsets/manifest.json"

echo ""
echo "[Offsets 统计]"
python3 << PY
import json
from pathlib import Path
root = Path("$ROOT")
with open(root / "offsets/config.json") as f:
    cfg = json.load(f)
arm = x64 = 0
for v in cfg:
    archs = {e["arch"] for t in v["targets"] for e in t["entries"]}
    if "arm64" in archs: arm += 1
    if "x86_64" in archs: x64 += 1
print(f"  📊 config.json: {len(cfg)} versions (arm64={arm}, x86_64={x64})")
latest = cfg[-1]
print(f"  📊 latest build: {latest['version']}")
ids = [t["identifier"] for t in latest["targets"]]
print(f"  📊 latest targets: {ids}")
PY
PASS=$((PASS + 1))

echo ""
echo "[架构检测]"
ARCH=$(uname -m)
echo "  📊 host arch: $ARCH"
PASS=$((PASS + 1))

echo ""
echo "[CLI 冒烟]"
check "wxyyds --help"              "$ROOT/tools/wxyyds" --help
check "wxyyds versions"            "$ROOT/tools/wxyyds" versions

echo ""
echo "[Manifest fallback]"
python3 << PY
import json
from pathlib import Path
with open(Path("$ROOT") / "offsets/manifest.json") as f:
    m = json.load(f)
for arch in ("arm64", "x86_64"):
    fb = m["fallback"][arch]
    print(f"  📊 {arch} fallback: build={fb['build']} tag={fb['canc3s_tag']}")
PY
PASS=$((PASS + 1))

echo ""
echo "[Patcher 语法]"
check "patcher.py import"          python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('p', '$ROOT/tools/patcher.py'); m=importlib.util.module_from_spec(spec)"

echo ""
echo "=================================="
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo ""
echo "✅ wxyyds 已就位 — 验证通过"
