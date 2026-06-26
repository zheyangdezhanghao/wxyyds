#!/usr/bin/env python3
"""
wxyyds Mach-O patcher — port of WeChatTweak Patcher.swift
修复: Resources/wechat.dylib 使用 slice 相对偏移寻址
"""

from __future__ import annotations

import json
import struct
import sys
import os
from pathlib import Path
from typing import Any

MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA
LC_SEGMENT_64 = 0x19
CPU_TYPE_ARM64 = 0x0100000C
CPU_TYPE_X86_64 = 0x01000007

ARCH_MAP = {
    "arm64": CPU_TYPE_ARM64,
    "x86_64": CPU_TYPE_X86_64,
}

# 微信 4.1.x Resources/wechat.dylib 的 Mach-O 段表异常 (多个 vmaddr=0)
# config 中的 addr 实为 slice 内文件偏移，非标准 VA
SLICE_RELATIVE_BINARIES = (
    "Contents/Resources/wechat.dylib",
)


class PatcherError(Exception):
    pass


def hex_to_bytes(hex_str: str) -> bytes:
    hex_str = hex_str.strip()
    if len(hex_str) % 2:
        raise PatcherError(f"Invalid hex: {hex_str}")
    return bytes.fromhex(hex_str)


def read_u32_be(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def read_u32_le(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def read_u64_le(data: bytes, offset: int) -> int:
    return struct.unpack_from("<Q", data, offset)[0]


def uses_slice_relative(binary_rel: str) -> bool:
    return binary_rel in SLICE_RELATIVE_BINARIES


def find_va_file_offset_segment(
    data: bytes, slice_offset: int, target_va: int
) -> int:
    hdr_off = slice_offset
    ncmds = read_u32_le(data, hdr_off + 16)
    lc_offset = hdr_off + 32

    for _ in range(ncmds):
        cmd = read_u32_le(data, lc_offset)
        cmdsize = read_u32_le(data, lc_offset + 4)

        if cmd == LC_SEGMENT_64:
            # segname[16] @ +8 → vmaddr @ +24
            vmaddr = read_u64_le(data, lc_offset + 24)
            vmsize = read_u64_le(data, lc_offset + 32)
            fileoff = read_u64_le(data, lc_offset + 40)

            if vmaddr <= target_va < vmaddr + vmsize:
                return slice_offset + fileoff + (target_va - vmaddr)

        lc_offset += cmdsize

    raise PatcherError(f"VA 0x{target_va:x} not found in slice at 0x{slice_offset:x}")


def resolve_file_offset(
    data: bytes,
    slice_offset: int,
    target_va: int,
    binary_rel: str,
    ident: str,
) -> int:
    if uses_slice_relative(binary_rel):
        fo = slice_offset + target_va
        if fo + 6 > len(data):
            raise PatcherError(f"slice-relative offset out of range: {hex(fo)}")
        return fo

    return find_va_file_offset_segment(data, slice_offset, target_va)


def verify_patch_site(ident: str, original: bytes, arch: str = "") -> None:
    """启发式校验，避免再次 patch 到数据段"""
    if not original:
        raise PatcherError(f"patch site for {ident} is empty (bad file offset?)")

    is_arm = arch == "arm64" or (
        len(original) >= 4
        and original[-2:] == bytes.fromhex("5fd6")  # ret insn (AArch64)
    )

    if is_arm:
        # mov w0,#0/w1,#1; ret  — 已 patch
        if original in (
            bytes.fromhex("00008052C0035FD6"),
            bytes.fromhex("20008052C0035FD6"),
        ):
            return
        # stp / sub sp 等常见函数序言 (AArch64)
        if original[0] in (0xFD, 0xFF, 0xF9, 0xA9, 0xD1):
            return
    else:
        if ident == "multiInstance":
            # 应为条件跳转 jz/jnz (0f 84/0f 85) 或 call 序言
            if len(original) >= 2 and original[0] == 0x0F and original[1] in (0x84, 0x85):
                return
            if original[:2] in (bytes.fromhex("4c89"), bytes.fromhex("4889")):
                return  # 旧版可能 patch 函数头
        if ident == "revoke":
            # 函数序言 push rbp / sub rsp 等
            if original[0] in (0x55, 0x48, 0x40, 0x53):
                return
        # 已 patch 过 (x86)
        if original[:3] == bytes.fromhex("b80100") or original[:3] == bytes.fromhex("909090"):
            return

    warn = (
        f"patch site for {ident} looks unusual: {original[:8].hex()} "
        f"(continuing anyway)"
    )
    print(f"WARN: {warn}")


def patch_slice(
    data: bytearray,
    slice_offset: int,
    arch_name: str,
    ident: str,
    target_va: int,
    patch: bytes,
    binary_rel: str,
) -> None:
    file_offset = resolve_file_offset(data, slice_offset, target_va, binary_rel, ident)
    original = bytes(data[file_offset : file_offset + len(patch)])
    verify_patch_site(ident, original, arch_name)

    mode = "slice+offset" if uses_slice_relative(binary_rel) else "segment"
    print(
        f"[{arch_name}/{ident}] mode={mode} "
        f"addr=0x{target_va:x} -> fileoff=0x{file_offset:x} "
        f"was={original.hex()} now={patch.hex()}"
    )
    data[file_offset : file_offset + len(patch)] = patch


def get_fat_slice_offset(data: bytes, cpu_type: int) -> int:
    magic_be = read_u32_be(data, 0)
    if magic_be not in (FAT_MAGIC, FAT_CIGAM):
        raise PatcherError("Not a fat binary")

    swapped = magic_be == FAT_CIGAM
    nfat = read_u32_be(data, 4) if not swapped else int.from_bytes(data[4:8], "little")

    off = 8
    for _ in range(nfat):
        if swapped:
            cputype = int.from_bytes(data[off : off + 4], "little")
            slice_off = int.from_bytes(data[off + 8 : off + 12], "little")
        else:
            cputype = read_u32_be(data, off)
            slice_off = read_u32_be(data, off + 8)
        if cputype == cpu_type:
            return slice_off
        off += 20

    raise PatcherError(f"No slice for cpu_type 0x{cpu_type:x}")


def patch_binary(
    binary_path: Path,
    config: dict[str, Any],
    host_arch: str,
    binary_rel: str,
) -> int:
    data = bytearray(binary_path.read_bytes())
    if len(data) < 4:
        raise PatcherError(f"Invalid file: {binary_path}")

    magic_be = read_u32_be(data, 0)
    patched = 0
    cpu_type = ARCH_MAP.get(host_arch)
    if cpu_type is None:
        raise PatcherError(f"Unsupported host arch: {host_arch}")

    entries: list[tuple[str, int, bytes]] = []
    only_ids = os.environ.get("WXYYDS_PATCH_IDS", "").strip()
    allowed = {x.strip() for x in only_ids.split(",") if x.strip()} if only_ids else None

    for target in config.get("targets", []):
        ident = target.get("identifier", "?")
        if allowed is not None and ident not in allowed:
            continue
        for entry in target.get("entries", []):
            if entry.get("arch") != host_arch:
                continue
            addr = int(entry["addr"], 16)
            asm = hex_to_bytes(entry["asm"])
            entries.append((ident, addr, asm))

    if not entries:
        raise PatcherError(f"No patch entries for arch {host_arch}")

    if magic_be in (FAT_MAGIC, FAT_CIGAM):
        slice_offset = get_fat_slice_offset(data, cpu_type)
        for ident, addr, asm in entries:
            patch_slice(
                data, slice_offset, host_arch, ident, addr, asm, binary_rel
            )
            patched += 1
    else:
        magic_le = read_u32_le(data, 0)
        if magic_le != MH_MAGIC_64:
            raise PatcherError(f"Not 64-bit Mach-O: magic=0x{magic_le:x}")

        cputype = read_u32_le(data, 4)
        if cputype != cpu_type:
            raise PatcherError(f"Binary arch mismatch: expected {host_arch}")

        for ident, addr, asm in entries:
            patch_slice(data, 0, host_arch, ident, addr, asm, binary_rel)
            patched += 1

    binary_path.write_bytes(data)
    return patched


def load_config(config_path: Path) -> list[dict[str, Any]]:
    with config_path.open() as f:
        return json.load(f)


def find_config(configs: list[dict[str, Any]], build: str, host_arch: str) -> dict[str, Any] | None:
    for cfg in configs:
        if cfg.get("version") != build:
            continue
        for target in cfg.get("targets", []):
            for entry in target.get("entries", []):
                if entry.get("arch") == host_arch:
                    return cfg
    return None


def patch_app(
    app_path: Path,
    config_path: Path,
    build: str,
    host_arch: str,
) -> None:
    configs = load_config(config_path)
    cfg = find_config(configs, build, host_arch)
    if not cfg:
        raise PatcherError(f"Unsupported version {build} for {host_arch}")

    default_binary = "Contents/MacOS/WeChat"
    grouped: dict[str, list[dict[str, Any]]] = {}
    for target in cfg["targets"]:
        binary = target.get("binary", default_binary)
        grouped.setdefault(binary, []).append(target)

    total = 0
    for binary, targets in grouped.items():
        sub_cfg = {"version": cfg["version"], "targets": targets}
        bin_path = app_path / binary
        if not bin_path.exists():
            raise PatcherError(f"Binary not found: {bin_path}")
        print(f"Patching {bin_path} ...")
        total += patch_binary(bin_path, sub_cfg, host_arch, binary)

    print(f"Done! {total} patch(es) applied.")


# 微信 4.1.x Resources/wechat.dylib: config addr = slice 内文件偏移
# x86_64 slice offset 因版本而异 (0x1000 或 0x4000)，通过 FAT header 动态读取

def verify_patches(
    app_path: Path,
    config_path: Path,
    build: str,
    host_arch: str,
    only_ids: set[str] | None = None,
) -> bool:
    """安装后校验 patch 是否在正确代码位置"""
    configs = load_config(config_path)
    cfg = find_config(configs, build, host_arch)
    if not cfg:
        return False

    ok = True
    default_binary = "Contents/MacOS/WeChat"
    for target in cfg["targets"]:
        if only_ids is not None and target["identifier"] not in only_ids:
            continue
        binary = target.get("binary", default_binary)
        bin_path = app_path / binary
        data = bin_path.read_bytes()
        for entry in target.get("entries", []):
            if entry.get("arch") != host_arch:
                continue
            addr = int(entry["addr"], 16)
            expected = hex_to_bytes(entry["asm"])
            magic_be = read_u32_be(data, 0)
            if uses_slice_relative(binary):
                if magic_be in (FAT_MAGIC, FAT_CIGAM):
                    slice_off = get_fat_slice_offset(data, ARCH_MAP[host_arch])
                    fo = slice_off + addr
                else:
                    fo = addr
            else:
                slice_off = (
                    get_fat_slice_offset(data, ARCH_MAP[host_arch])
                    if magic_be in (FAT_MAGIC, FAT_CIGAM)
                    else 0
                )
                fo = resolve_file_offset(
                    data, slice_off, addr, binary, target["identifier"]
                )
            actual = data[fo : fo + len(expected)]
            if actual != expected:
                print(f"VERIFY FAIL {target['identifier']} @ {hex(fo)}: {actual.hex()} != {expected.hex()}")
                ok = False
            else:
                print(f"VERIFY OK   {target['identifier']} @ {hex(fo)}")
    return ok


def main() -> int:
    if len(sys.argv) < 5:
        print(
            "Usage: patcher.py <WeChat.app> <config.json> <CFBundleVersion> <arch> [verify]",
            file=sys.stderr,
        )
        return 1

    app = Path(sys.argv[1])
    config = Path(sys.argv[2])
    build = sys.argv[3]
    arch = sys.argv[4]

    try:
        if len(sys.argv) > 5 and sys.argv[5] == "verify":
            only_ids = None
            env_ids = os.environ.get("WXYYDS_PATCH_IDS", "").strip()
            if env_ids:
                only_ids = {x.strip() for x in env_ids.split(",") if x.strip()}
            return 0 if verify_patches(app, config, build, arch, only_ids) else 1
        patch_app(app, config, build, arch)
        only_ids = None
        env_ids = os.environ.get("WXYYDS_PATCH_IDS", "").strip()
        if env_ids:
            only_ids = {x.strip() for x in env_ids.split(",") if x.strip()}
        if not verify_patches(app, config, build, arch, only_ids):
            raise PatcherError("Post-patch verification failed")
        return 0
    except PatcherError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
