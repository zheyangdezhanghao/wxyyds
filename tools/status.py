#!/usr/bin/env python3
"""wxyyds 功能状态检测 — 根据当前微信版本与架构报告可用模块"""

from __future__ import annotations

import json
import plistlib
import platform
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "offsets/config.json"
APP = Path("/Applications/WeChat.app")
HOOK_LOG = Path("/tmp/wxyyds-hook.log")

PATCH_MODULES = {
    "revoke": ("RecallGuard", "防撤回", "✅ 稳定"),
    "multiInstance": ("MultiGate", "多开", "✅ 稳定"),
}

FREEZE_PATCH_IDS = {
    "startUpdater", "startBackgroundUpdatesCheck", "checkForUpdates",
    "enableAutoUpdate", "automaticallyDownloadsUpdates", "canCheckForUpdate",
}

FRAMEWORK_MODULES = {
    "RecallNotify": ("撤回提醒", "✅ Swizzle"),
    "RecallSync": ("撤回同步文件助手", "✅ Swizzle"),
    "ExitWatch": ("退群提醒", "✅ Swizzle"),
    "OpenLink": ("系统浏览器", "✅ Swizzle"),
    "TimeStamp+": ("消息时间戳", "✅ Swizzle"),
    "FreezeLock": ("禁更新", "✅ Swizzle"),
    "GhostCheck": ("好友状态检测", "✅ Swizzle"),
    "KeywordAlert": ("群关键词提醒", "✅ Swizzle"),
    "FoldPro": ("群智能折叠", "✅ Swizzle"),
}


def has_wxyyds_framework() -> bool:
    fw = APP / "Contents/MacOS/WXYyds.framework/WXYyds"
    binary = APP / "Contents/MacOS/WeChat"
    if not fw.exists():
        return False
    try:
        r = subprocess.run(["otool", "-L", str(binary)], capture_output=True, text=True)
        return "WXYyds" in r.stdout
    except Exception:
        return False


def hook_log_has(module: str) -> bool:
    if not HOOK_LOG.exists():
        return False
    try:
        text = HOOK_LOG.read_text(encoding="utf-8", errors="replace")
        return f"{module} installed" in text
    except OSError:
        return False


def main() -> int:
    arch = "arm64" if platform.machine().lower() in ("arm64", "aarch64") else "x86_64"

    if not APP.exists():
        print("WeChat.app 未找到")
        return 1

    with (APP / "Contents/Info.plist").open("rb") as f:
        pl = plistlib.load(f)
    build = str(pl.get("CFBundleVersion", ""))
    short = str(pl.get("CFBundleShortVersionString", ""))

    with CONFIG.open() as f:
        configs = json.load(f)

    active_ids: set[str] = set()
    for cfg in configs:
        if cfg.get("version") != build:
            continue
        for t in cfg.get("targets", []):
            for e in t.get("entries", []):
                if e.get("arch") == arch:
                    active_ids.add(t["identifier"])

    hook_on = has_wxyyds_framework()

    print("wxyyds 功能状态 — 一个极客的理想之地")
    print("=" * 50)
    print(f"微信: {short} (build {build})")
    print(f"架构: {arch}")
    print(f"Framework: {'已注入' if hook_on else '未注入'}")
    print()

    print("【Binary Patch】")
    shown: set[str] = set()
    for ident in sorted(active_ids):
        if ident in PATCH_MODULES:
            code, name, status = PATCH_MODULES[ident]
            if code in shown:
                continue
            shown.add(code)
            print(f"  ✅ {code:12} {name:10} {status}")
    if active_ids & FREEZE_PATCH_IDS:
        print("  ✅ FreezeLock   禁更新      ✅ Patch")
    elif not hook_on:
        print("  ⚠️  FreezeLock   禁更新      未启用 (需 Framework 或 patch offsets)")

    print()
    print("【Framework 模块】")
    if hook_on:
        for code, (name, status) in FRAMEWORK_MODULES.items():
            log_ok = hook_log_has(code.replace("+", "")) or hook_log_has(code)
            mark = "✅" if log_ok else "⚡"
            print(f"  {mark} {code:12} {name:14} {status}")
        print()
        print("  ℹ️  日志: tail -f /tmp/wxyyds-hook.log")
        print("  ℹ️  RecallSync 日志: /tmp/wxyyds-recall-sync.log")
        print("  ℹ️  配置: ~/.wxyyds/config.json")
    else:
        print("  ❌ Framework 未注入 — 运行 bash install.sh 启用完整功能")
        print("  ℹ️  仅 patch: bash install.sh --patch-only")

    print()
    print("验证方式:")
    print("  防撤回: 好友发消息再撤回，Mac 应仍显示")
    print("  多开:   open -n /Applications/WeChat.app")
    print("  全量:   bash scripts/verify.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
