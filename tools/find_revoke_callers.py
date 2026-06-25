#!/usr/bin/env python3
import struct
from pathlib import Path

SLICE = 0x4000
TARGET = 0x4F4D4C0
data = Path("/Applications/WeChat.app/Contents/Resources/wechat.dylib").read_bytes()
hits = []
for i in range(SLICE, SLICE + 0x9D309C0):
    if data[i] != 0xE8:
        continue
    rel = struct.unpack_from("<i", data, i + 1)[0]
    if (i - SLICE + 5) + rel == TARGET:
        hits.append(i - SLICE)
print(f"callers {len(hits)}")
for h in hits:
    print(hex(h))
