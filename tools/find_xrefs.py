#!/usr/bin/env python3
"""Find RIP-relative xrefs to a VA in wechat.dylib x86_64 slice."""
import struct
import sys
from pathlib import Path

SLICE_BASE = 0x4000
TEXT_END = 0x9D309C0  # rough __TEXT size


def rip_refs(data: bytes, target_va: int, text_start: int, text_end: int):
    hits = []
    for i in range(text_start, min(text_end, len(data) - 7)):
        b0, b1, b2 = data[i], data[i + 1], data[i + 2]
        # lea/mov rip-relative: REX.W + 8d/8b + modrm 05/0d/15/1d/25/2d/35/3d
        if b0 != 0x48 or b2 not in (0x05, 0x0D, 0x15, 0x1D, 0x25, 0x2D, 0x35, 0x3D):
            continue
        if b1 not in (0x8D, 0x8B):
            continue
        disp = struct.unpack_from("<i", data, i + 3)[0]
        insn_end = i + 7
        va = (insn_end - SLICE_BASE) + disp
        if va == target_va:
            hits.append((insn_end - SLICE_BASE - 7, b1, b2))
    return hits


def main():
    dylib = Path("/Applications/WeChat.app/Contents/Resources/wechat.dylib")
    data = dylib.read_bytes()

    strings = {
        "paymsg@375b13b": 0x375B13B - SLICE_BASE,
        "paymsg@501da4b": 0x501DA4B - SLICE_BASE,
        "paymsg@501f06e": 0x501F06E - SLICE_BASE,
    }

    for name, va in strings.items():
        refs = rip_refs(data, va, SLICE_BASE, SLICE_BASE + TEXT_END)
        print(f"\n{name} va={va:#x} refs={len(refs)}")
        for fn_va, b1, b2 in refs[:20]:
            kind = "lea" if b1 == 0x8D else "mov"
            print(f"  {fn_va:#x}  {kind} rip-rel")

    # Also find refs to hook slot area
    slot = 0x94D574F
    refs = rip_refs(data, slot, SLICE_BASE, SLICE_BASE + TEXT_END)
    print(f"\nhook slot {slot:#x} refs={len(refs)}")
    for fn_va, _, _ in refs[:10]:
        print(f"  {fn_va:#x}")


if __name__ == "__main__":
    main()
