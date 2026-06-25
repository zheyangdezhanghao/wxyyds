#!/usr/bin/env python3
"""Dump ObjC class names from WeChat binaries matching keywords."""
import re
import subprocess
import sys
from pathlib import Path

BIN = Path("/Applications/WeChat.app/Contents/Resources/wechat.dylib")
KW = re.compile(
    r"revoke|message|contact|session|browser|fold|helper|timestamp|openurl|workspace",
    re.I,
)

def main() -> int:
    if not BIN.exists():
        print(f"missing {BIN}", file=sys.stderr)
        return 1
    out = subprocess.run(
        ["nm", "-gU", str(BIN)],
        capture_output=True,
        text=True,
        errors="replace",
    )
    seen = set()
    for line in out.stdout.splitlines():
        if "OBJC_CLASS" not in line and "OBJC_METACLASS" not in line:
            continue
        m = re.search(r"_OBJC_CLASS_\$_(\S+)", line)
        if not m:
            continue
        name = m.group(1)
        if name in seen or not KW.search(name):
            continue
        seen.add(name)
        print(name)
    print(f"# total: {len(seen)}", file=sys.stderr)
    return 0

if __name__ == "__main__":
    sys.exit(main())
