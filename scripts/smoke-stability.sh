#!/bin/bash
# 安装后稳定性检查：二进制补丁 + 可选短时启动存活测试

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${WXYYDS_APP:-/Applications/WeChat.app}"
DYLIB="$APP_PATH/Contents/Resources/wechat.dylib"
BINARY="$APP_PATH/Contents/MacOS/WeChat"
PASS=0
FAIL=0
WARN=0

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

echo "wxyyds smoke-stability — 安装后稳定性检查"
echo "========================================"

if [ ! -d "$APP_PATH" ]; then
    echo "  ❌ WeChat.app not found at $APP_PATH"
    exit 1
fi

echo ""
echo "[二进制状态]"
check "wechat.dylib exists" test -f "$DYLIB"
check "WeChat binary exists" test -f "$BINARY"

read -r PY_PASS PY_FAIL < <(python3 << PY
import subprocess
import sys
from pathlib import Path

dylib = Path("$DYLIB")
binary = Path("$BINARY")
pass_n = fail_n = 0

def ok(msg):
    global pass_n
    print(f"  ✅ {msg}", file=sys.stderr)
    pass_n += 1

def bad(msg):
    global fail_n
    print(f"  ❌ {msg}", file=sys.stderr)
    fail_n += 1

framework_mode = False
if binary.exists():
    otool = subprocess.run(
        ["otool", "-L", str(binary)],
        capture_output=True,
        text=True,
        check=False,
    )
    framework_mode = "WXYyds" in (otool.stdout or "")

if dylib.exists():
    b = dylib.read_bytes()
    revoke = b[0x4000 + 0x4F4D4C0:0x4000 + 0x4F4D4C0 + 6].hex()
    multi = b[0x4000 + 0x247B08:0x4000 + 0x247B08 + 6].hex()
    call_site = b[0x4000 + 0x4F4D44E:0x4000 + 0x4F4D44E + 5].hex()

    if revoke == "b801000000c3":
        ok("revoke handler patched (RecallGuard static)")
    elif revoke.startswith("554889") and framework_mode:
        ok("revoke handler original prologue (Framework pointer hook 灰字)")
    elif revoke.startswith("554889"):
        bad("revoke handler NOT patched (RecallGuard inactive)")
    else:
        bad(f"revoke handler unknown bytes: {revoke}")

    if multi == "909090909090":
        ok("multiInstance patched (MultiGate)")
    else:
        bad(f"multiInstance NOT patched: {multi}")

    if call_site.startswith("e8"):
        ok("revoke call-site intact (no runtime hook patch)")
    else:
        bad(f"revoke call-site modified: {call_site}")

print(pass_n, fail_n)
PY
)
PASS=$((PASS + PY_PASS))
FAIL=$((FAIL + PY_FAIL))

echo ""
echo "[Framework 注入]"
FW="$APP_PATH/Contents/MacOS/WXYyds.framework/WXYyds"
if otool -L "$BINARY" 2>/dev/null | grep -qi wxyyds; then
    if [ -f "$FW" ]; then
        echo "  ✅ WXYyds.framework 已注入 (Intel 269077 灰字模式)"
        PASS=$((PASS + 1))
    else
        echo "  ❌ 二进制已注入但 Framework 文件缺失"
        FAIL=$((FAIL + 1))
    fi
else
    if [ -f "$FW" ]; then
        echo "  ⚠️  Framework 在磁盘上但未注入 WeChat 二进制"
        WARN=$((WARN + 1))
    else
        echo "  ✅ 无 Framework 注入 (patch-only 模式)"
        PASS=$((PASS + 1))
    fi
fi

echo ""
echo "[Hook 日志]"
if [ -f /tmp/wxyyds-hook.log ]; then
    if grep -q "call-site hook installed" /tmp/wxyyds-hook.log 2>/dev/null; then
        echo "  ⚠️  历史日志含 call-site hook（旧版，已禁用；可 rm /tmp/wxyyds-hook.log 清除）"
        WARN=$((WARN + 1))
    elif grep -q "RevokeInChat: overwrite slot" /tmp/wxyyds-hook.log 2>/dev/null; then
        if python3 -c "
from pathlib import Path
import subprocess
b = Path('$DYLIB').read_bytes()
revoke = b[0x4000 + 0x4F4D4C0:0x4000 + 0x4F4D4C0 + 6].hex()
binary = Path('$BINARY')
fw = binary.exists() and 'WXYyds' in subprocess.check_output(['otool','-L',str(binary)], text=True, stderr=subprocess.DEVNULL)
if revoke == 'b801000000c3' and fw:
    raise SystemExit(0)
raise SystemExit(1)
" 2>/dev/null; then
            echo "  ℹ️  历史日志含指针 Hook，当前为稳定模式（静态 RecallGuard）"
            PASS=$((PASS + 1))
        else
            echo "  ✅ RevokeInChat 指针 Hook 已写入"
            PASS=$((PASS + 1))
        fi
    else
        echo "  ✅ 无 call-site hook 记录"
        PASS=$((PASS + 1))
    fi
    last="$(tail -1 /tmp/wxyyds-hook.log 2>/dev/null || true)"
    [ -n "$last" ] && echo "  📋 latest: $last"
else
    echo "  ℹ️  无 /tmp/wxyyds-hook.log（首次安装正常）"
fi

echo ""
echo "[可选启动存活测试]"
if [ "${WXYYDS_SMOKE_LAUNCH:-0}" = "1" ]; then
    echo "  启动 WeChat 并观察 15 秒 ..."
    killall WeChat 2>/dev/null || true
    sleep 1
    open -a "$APP_PATH" || true
    sleep 3
    alive=0
    for _ in $(seq 1 12); do
        if pgrep -x WeChat >/dev/null 2>&1 || pgrep -f 'WeChatAppEx.app/Contents/MacOS/WeChatAppEx ' >/dev/null 2>&1; then
            alive=1
        else
            alive=0
            break
        fi
        sleep 1
    done
    if [ "$alive" -eq 1 ]; then
        echo "  ✅ WeChat 进程存活 ≥15s"
        PASS=$((PASS + 1))
    else
        echo "  ❌ WeChat 启动后快速退出"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  ℹ️  跳过（设置 WXYYDS_SMOKE_LAUNCH=1 启用）"
fi

echo ""
echo "========================================"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo ""
echo "✅ 稳定性检查通过"
