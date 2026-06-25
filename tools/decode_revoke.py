#!/usr/bin/env python3
import struct
from pathlib import Path

SLICE = 0x4000
data = Path("/Applications/WeChat.app/Contents/Resources/wechat.dylib").read_bytes()

def decode_from(va, n=200):
    i = va
    end = va + n
    while i < end:
        b = data[SLICE + i : SLICE + i + 16]
        print(f"{i:08x}: {b.hex()}")
        if b[0] == 0xE8:
            rel = struct.unpack_from("<i", b, 1)[0]
            print(f"         call -> {i + 5 + rel:#x}")
            i += 5
            continue
        if b[0:2] == bytes([0x48, 0x8B]) and b[2] in range(0x05, 0x40, 8):
            rel = struct.unpack_from("<i", b, 3)[0]
            print(f"         mov reg, [rip+{rel:#x}] -> [{i + 7 + rel:#x}]")
            i += 7
            continue
        if b[0:3] == bytes([0x48, 0x8D]) and b[2] in range(0x05, 0x40, 8):
            rel = struct.unpack_from("<i", b, 3)[0]
            print(f"         lea reg, [rip+{rel:#x}] -> [{i + 7 + rel:#x}]")
            i += 7
            continue
        if b[0] == 0x0F and b[1] == 0x28 and b[2] == 0x05:
            rel = struct.unpack_from("<i", b, 3)[0]
            print(f"         movaps xmm0, [rip+{rel:#x}] -> [{i + 7 + rel:#x}]")
            i += 7
            continue
        i += 1

decode_from(0x4F4D4C0, 250)
