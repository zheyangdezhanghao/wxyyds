#!/bin/bash
# Intel 269077 聊天内灰字 — 静态验证（JSON/编译/部分 patch 流程）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "test-recall-inchat — Intel 269077 灰字 RE"
echo "=========================================="

echo ""
echo "[hook_269077.json 结构]"
python3 << PY
import json, sys
from pathlib import Path
hook = json.load(open("$ROOT/offsets/hook_269077.json"))
required = [
    "version", "arch", "hookPointerSlotVA", "revokeHandlerVA",
    "insertPaySysMsgToSessionVA", "messageWrapFromRawVA",
    "messageWrapDestructVA", "rawMessageTemplateVA", "layout",
]
missing = [k for k in required if k not in hook]
if missing:
    print("  ❌ missing keys:", missing); sys.exit(1)
if hook["version"] != "269077" or hook["arch"] != "x86_64":
    print("  ❌ version/arch mismatch"); sys.exit(1)
layout = hook["layout"]
for k in ("remoteUserOrSessionOffset", "selfUserOffset", "contentOffset", "createTimeSecOffset"):
    if k not in layout:
        print("  ❌ layout missing", k); sys.exit(1)
print("  ✅ hook profile schema OK")
PY
PASS=$((PASS + 1))

echo ""
echo "[WXRevokeInChat 内嵌偏移与 JSON 一致]"
python3 << PY
import json, re, sys
from pathlib import Path
hook = json.load(open("$ROOT/offsets/hook_269077.json"))
src = Path("$ROOT/WXYydsHook/Modules/WXRevokeInChat.mm").read_text()
pairs = {
    "hookPointerVA": int(hook["hookPointerSlotVA"], 16),
    "revokeHandlerVA": int(hook["revokeHandlerVA"], 16),
    "rawMessageTemplateVA": int(hook["rawMessageTemplateVA"], 16),
    "messageWrapFromRawVA": int(hook["messageWrapFromRawVA"], 16),
    "messageWrapDestructVA": int(hook["messageWrapDestructVA"], 16),
    "insertPaySysMsgToSessionVA": int(hook["insertPaySysMsgToSessionVA"], 16),
}
for name, va in pairs.items():
    pat = rf"\.{name}\s*=\s*0x{va:x}"
    if not re.search(pat, src, re.I):
        print(f"  ❌ {name} not embedded as 0x{va:x}"); sys.exit(1)
if f"buildVersion = \"269077\"" not in src.replace(" ", ""):
    if '.buildVersion = "269077"' not in src:
        print("  ❌ buildVersion 269077 missing"); sys.exit(1)
print("  ✅ embedded profile matches hook_269077.json")
PY
PASS=$((PASS + 1))

echo ""
echo "[x86_64 Framework 编译]"
if WXYYDS_BUILD_ARCH=x86_64 bash "$ROOT/WXYydsHook/build.sh" >/tmp/wxyyds-x64-build.log 2>&1; then
    FW="$ROOT/Rely/Plugin/WXYyds.framework/Versions/A/WXYyds"
    if file "$FW" | grep -q x86_64; then
        ok "WXYyds.framework x86_64"
        if nm -gU "$FW" 2>/dev/null | grep -q WXInstallRevokeInChat; then
            ok "WXInstallRevokeInChat symbol exported"
        else
            bad "WXInstallRevokeInChat symbol missing"
        fi
        if [ -f "$ROOT/Rely/Plugin/WXYyds.framework/Versions/A/Resources/hook_269077.json" ]; then
            ok "hook_269077.json bundled in framework"
        else
            bad "hook_269077.json not in framework Resources"
        fi
    else
        bad "framework arch is not x86_64: $(file "$FW")"
    fi
else
    bad "x86_64 build failed — see /tmp/wxyyds-x64-build.log"
fi

echo ""
echo "[multiInstance-only patch 流程（临时副本）]"
APP="${WXYYDS_APP:-/Applications/WeChat.app}"
if [ ! -f "$APP/Contents/Resources/wechat.dylib" ]; then
    echo "  ℹ️  未安装 WeChat，跳过 patch 副本测试"
else
    TMP="/tmp/wxyyds-recall-test-$$"
    mkdir -p "$TMP/WeChat.app/Contents/Resources"
    cp "$APP/Contents/Resources/wechat.dylib" "$TMP/WeChat.app/Contents/Resources/"
    if WXYYDS_PATCH_IDS=multiInstance python3 "$ROOT/tools/patcher.py" \
        "$TMP/WeChat.app" "$ROOT/offsets/config.json" 269077 x86_64 >/tmp/wxyyds-recall-patch.log 2>&1; then
        ok "patcher multiInstance-only apply"
        if WXYYDS_PATCH_IDS=multiInstance python3 "$ROOT/tools/patcher.py" \
            "$TMP/WeChat.app" "$ROOT/offsets/config.json" 269077 x86_64 verify >/tmp/wxyyds-recall-verify.log 2>&1; then
            ok "patcher multiInstance-only verify"
        else
            bad "multiInstance verify failed"
            tail -5 /tmp/wxyyds-recall-verify.log | sed 's/^/     /'
        fi
        python3 << PY
from pathlib import Path
from tools.patcher import get_fat_slice_offset, resolve_file_offset, ARCH_MAP
p = Path("$TMP/WeChat.app/Contents/Resources/wechat.dylib")
data = p.read_bytes()
so = get_fat_slice_offset(data, ARCH_MAP["x86_64"])
revoke_fo = resolve_file_offset(data, so, 0x4F4D4C0, "Contents/Resources/wechat.dylib", "revoke")
revoke = data[revoke_fo:revoke_fo+6]
if revoke.hex().startswith("b80100"):
    print("  ❌ revoke was static-patched (should be skipped in framework mode)")
    raise SystemExit(1)
print("  ✅ revoke handler not static-patched after multiInstance-only")
PY
        PASS=$((PASS + 1))
    else
        bad "patcher multiInstance-only failed"
        tail -8 /tmp/wxyyds-recall-patch.log | sed 's/^/     /'
    fi
    rm -rf "$TMP"
fi

echo ""
echo "=========================================="
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
