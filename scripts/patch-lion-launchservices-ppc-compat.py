#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import stat
import struct
import sys

EXPECTED_FULL_SHA256 = "ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5"
EXPECTED_I386_SHA256 = "e690d40ac70973ad7e7945f93c4a2e85ede5422474c885377bd2552ae3eaa735"

CPU_TYPE_I386 = 7
LC_SEGMENT = 0x1

# Validated Lion 10.7.5 i386 LaunchServices addresses from the provenance audit.
FUNCTION_VADDR = 0x000303d4
CMP_VADDR = 0x0003043a
TEST_VADDR = 0x00030441
PATCH_VADDR = 0x00030446

# _LSBundleDataGetUnsupportedFormatFlag, x86_64-host branch:
#
#   0003043a  cmpl   $0x01000007,%eax
#   0003043f  jne    0x0003045e
#   00030441  testl  $0x14000000,%ebx
#
# The experiment changes only the final immediate byte of the TEST instruction,
# making the mask 0x16000000 and therefore adding the PPC bit 0x02000000.
EXPECTED_CMP_BRANCH = b"\x3d\x07\x00\x00\x01\x75\x1d"
ORIGINAL_TEST = b"\xf7\xc3\x00\x00\x00\x14"
PATCHED_TEST = b"\xf7\xc3\x00\x00\x00\x16"


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def read_file(path):
    with open(path, "rb") as f:
        return f.read()


def write_file(path, data, mode):
    with open(path, "wb") as f:
        f.write(data)
    os.chmod(path, mode)


def bytearray_to_bytes(buf):
    if sys.version_info[0] < 3:
        return buffer(buf)[:]
    return bytes(buf)


def parse_i386_range(data):
    if len(data) < 8:
        raise ValueError("file too small")

    magic = data[:4]

    # Fat headers are big-endian on disk.
    if magic == b"\xca\xfe\xba\xbe":
        nfat = struct.unpack_from(">I", data, 4)[0]
        off = 8
        matches = []
        for i in range(nfat):
            if off + 20 > len(data):
                raise ValueError("truncated fat_arch table")
            cputype, cpusubtype, arch_off, arch_size, align = struct.unpack_from(">iiIII", data, off)
            if cputype == CPU_TYPE_I386:
                matches.append((arch_off, arch_size, cpusubtype))
            off += 20
        if len(matches) != 1:
            raise ValueError("expected exactly one i386 fat slice, found %d" % len(matches))
        arch_off, arch_size, cpusubtype = matches[0]
        if arch_off + arch_size > len(data):
            raise ValueError("i386 slice extends past file")
        return arch_off, arch_size, cpusubtype

    # Thin little-endian MH_MAGIC.
    if magic == b"\xce\xfa\xed\xfe":
        cputype = struct.unpack_from("<i", data, 4)[0]
        cpusubtype = struct.unpack_from("<i", data, 8)[0]
        if cputype != CPU_TYPE_I386:
            raise ValueError("thin Mach-O is not i386")
        return 0, len(data), cpusubtype

    raise ValueError("unsupported Mach-O container magic %r" % (magic,))


def parse_mach_header(data, arch_off, arch_size):
    if arch_size < 28:
        raise ValueError("i386 slice too small for mach_header")

    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack_from(
        "<IiiIIII", data, arch_off
    )

    if magic != 0xfeedface:
        raise ValueError("i386 slice is not 32-bit little-endian MH_MAGIC")
    if cputype != CPU_TYPE_I386:
        raise ValueError("i386 slice cputype mismatch")
    if 28 + sizeofcmds > arch_size:
        raise ValueError("load commands extend past i386 slice")

    return {
        "magic": magic,
        "cputype": cputype,
        "cpusubtype": cpusubtype,
        "filetype": filetype,
        "ncmds": ncmds,
        "sizeofcmds": sizeofcmds,
        "flags": flags,
    }


def vaddr_to_file_offset(data, arch_off, arch_size, vaddr):
    hdr = parse_mach_header(data, arch_off, arch_size)
    cmd_off = arch_off + 28

    for i in range(hdr["ncmds"]):
        if cmd_off + 8 > arch_off + arch_size:
            raise ValueError("truncated load command header")

        cmd, cmdsize = struct.unpack_from("<II", data, cmd_off)
        if cmdsize < 8:
            raise ValueError("invalid load command size")
        if cmd_off + cmdsize > arch_off + arch_size:
            raise ValueError("load command extends past i386 slice")

        if cmd == LC_SEGMENT:
            if cmdsize < 56:
                raise ValueError("short LC_SEGMENT command")
            fields = struct.unpack_from("<II16sIIIIiiII", data, cmd_off)
            vmaddr = fields[3]
            vmsize = fields[4]
            fileoff = fields[5]
            filesize = fields[6]

            if vaddr >= vmaddr and vaddr < vmaddr + filesize:
                rel = vaddr - vmaddr
                if rel >= filesize:
                    raise ValueError("virtual address lies outside segment file data")
                result = arch_off + fileoff + rel
                if result >= arch_off + arch_size:
                    raise ValueError("mapped file offset lies outside i386 slice")
                return result

        cmd_off += cmdsize

    raise ValueError("virtual address 0x%x is not backed by an LC_SEGMENT file range" % vaddr)


def read_at_vaddr(data, arch_off, arch_size, vaddr, length):
    off = vaddr_to_file_offset(data, arch_off, arch_size, vaddr)
    end = off + length
    if end > arch_off + arch_size:
        raise ValueError("requested virtual range extends beyond i386 slice")
    return off, data[off:end]


def usage():
    print("usage: %s --check INPUT" % sys.argv[0], file=sys.stderr)
    print("       %s INPUT OUTPUT" % sys.argv[0], file=sys.stderr)
    return 64


def main():
    check_only = False

    if len(sys.argv) == 3 and sys.argv[1] == "--check":
        check_only = True
        src = sys.argv[2]
        dst = None
    elif len(sys.argv) == 3:
        src = sys.argv[1]
        dst = sys.argv[2]
    else:
        return usage()

    if not os.path.isfile(src):
        print("error: missing input: %s" % src, file=sys.stderr)
        return 66

    data = read_file(src)
    full_sha = sha256_bytes(data)

    print("input=%s" % src)
    print("input_size=%d" % len(data))
    print("input_sha256=%s" % full_sha)

    try:
        arch_off, arch_size, cpusubtype = parse_i386_range(data)
        parse_mach_header(data, arch_off, arch_size)

        i386 = data[arch_off:arch_off + arch_size]
        i386_sha = sha256_bytes(i386)

        cmp_off, cmp_bytes = read_at_vaddr(
            data, arch_off, arch_size, CMP_VADDR, len(EXPECTED_CMP_BRANCH)
        )
        test_off, test_bytes = read_at_vaddr(
            data, arch_off, arch_size, TEST_VADDR, len(ORIGINAL_TEST)
        )
        patch_off = vaddr_to_file_offset(data, arch_off, arch_size, PATCH_VADDR)
    except ValueError as e:
        print("error: %s" % e, file=sys.stderr)
        return 67

    print("i386_offset=0x%x" % arch_off)
    print("i386_size=%d" % arch_size)
    print("i386_cpusubtype=%d" % cpusubtype)
    print("i386_sha256=%s" % i386_sha)
    print("function_vaddr=0x%x" % FUNCTION_VADDR)
    print("cmp_vaddr=0x%x" % CMP_VADDR)
    print("cmp_file_offset=0x%x" % cmp_off)
    print("test_vaddr=0x%x" % TEST_VADDR)
    print("test_file_offset=0x%x" % test_off)
    print("patch_vaddr=0x%x" % PATCH_VADDR)
    print("patch_file_offset=0x%x" % patch_off)
    print("cmp_branch_bytes=%s" % cmp_bytes.encode("hex"))
    print("test_bytes=%s" % test_bytes.encode("hex"))

    if cmp_bytes != EXPECTED_CMP_BRANCH:
        print("RESULT: NOT_PATCHABLE")
        print("error: validated cmp/jne bytes do not match provenance audit", file=sys.stderr)
        return 69

    original_state = (test_bytes == ORIGINAL_TEST)
    patched_state = (test_bytes == PATCHED_TEST)

    if check_only:
        if original_state:
            if full_sha != EXPECTED_FULL_SHA256:
                print("RESULT: ORIGINAL_BYTES_BUT_UNEXPECTED_FILE_HASH")
                print("expected_sha256=%s" % EXPECTED_FULL_SHA256, file=sys.stderr)
                return 68
            if i386_sha != EXPECTED_I386_SHA256:
                print("RESULT: ORIGINAL_BYTES_BUT_UNEXPECTED_I386_HASH")
                print("expected_i386_sha256=%s" % EXPECTED_I386_SHA256, file=sys.stderr)
                return 68
            print("RESULT: PATCHABLE")
            return 0

        if patched_state:
            restored = bytearray(data)
            restored[patch_off] = 0x14
            restored = bytearray_to_bytes(restored)
            restored_sha = sha256_bytes(restored)
            print("restored_original_sha256=%s" % restored_sha)
            if restored_sha != EXPECTED_FULL_SHA256:
                print("RESULT: PATCHED_BYTES_BUT_NOT_VALIDATED_BASELINE")
                return 68
            print("RESULT: ALREADY_PATCHED")
            return 0

        print("RESULT: NOT_PATCHABLE")
        print("error: target TEST instruction bytes are neither original nor expected patched form", file=sys.stderr)
        return 69

    if full_sha != EXPECTED_FULL_SHA256:
        print("error: input is not the validated Lion 10.7.5 LaunchServices binary", file=sys.stderr)
        print("expected_sha256=%s" % EXPECTED_FULL_SHA256, file=sys.stderr)
        return 68

    if i386_sha != EXPECTED_I386_SHA256:
        print("error: i386 slice hash mismatch", file=sys.stderr)
        print("expected_i386_sha256=%s" % EXPECTED_I386_SHA256, file=sys.stderr)
        return 68

    if not original_state:
        print("error: target TEST instruction is not in the original state", file=sys.stderr)
        return 69

    if os.path.abspath(src) == os.path.abspath(dst):
        print("error: input and output must be different; system file is never patched in place", file=sys.stderr)
        return 64

    out = bytearray(data)
    old_byte = out[patch_off]
    if not isinstance(old_byte, int):
        old_byte = ord(old_byte)
    out[patch_off] = 0x16
    out = bytearray_to_bytes(out)

    diffs = []
    old_arr = bytearray(data)
    new_arr = bytearray(out)
    for i in range(len(old_arr)):
        if old_arr[i] != new_arr[i]:
            diffs.append(i)

    print("changed_byte_count=%d" % len(diffs))
    if len(diffs) != 1 or diffs[0] != patch_off:
        print("error: patch changed bytes outside the intended target", file=sys.stderr)
        return 70

    new_byte = new_arr[patch_off]
    if not isinstance(new_byte, int):
        new_byte = ord(new_byte)

    print("changed_file_offset=0x%x" % patch_off)
    print("old_byte=0x%02x" % old_byte)
    print("new_byte=0x%02x" % new_byte)

    if old_byte != 0x14 or new_byte != 0x16:
        print("error: unexpected patch delta", file=sys.stderr)
        return 70

    if out[:arch_off] != data[:arch_off]:
        print("error: bytes before i386 slice changed", file=sys.stderr)
        return 70
    if out[arch_off + arch_size:] != data[arch_off + arch_size:]:
        print("error: bytes after i386 slice changed", file=sys.stderr)
        return 70

    mode = stat.S_IMODE(os.stat(src).st_mode)
    write_file(dst, out, mode)

    verify = read_file(dst)
    verify_test_off, verify_test = read_at_vaddr(
        verify, arch_off, arch_size, TEST_VADDR, len(PATCHED_TEST)
    )

    print("output=%s" % dst)
    print("output_size=%d" % len(verify))
    print("output_sha256=%s" % sha256_bytes(verify))
    print("output_i386_sha256=%s" % sha256_bytes(verify[arch_off:arch_off + arch_size]))
    print("output_test_bytes=%s" % verify_test.encode("hex"))

    if verify_test != PATCHED_TEST:
        print("error: post-patch target instruction verification failed", file=sys.stderr)
        return 70

    restored = bytearray(verify)
    restored[patch_off] = 0x14
    restored = bytearray_to_bytes(restored)
    restored_sha = sha256_bytes(restored)
    print("restored_original_sha256=%s" % restored_sha)

    if restored_sha != EXPECTED_FULL_SHA256:
        print("error: patched output cannot be reconstructed to validated system baseline", file=sys.stderr)
        return 70

    print("RESULT: PASS")
    print("A private copy was patched. The input file was not modified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
