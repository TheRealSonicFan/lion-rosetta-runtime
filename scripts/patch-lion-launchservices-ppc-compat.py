#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import stat
import struct
import sys

EXPECTED_FULL_SHA256 = "ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5"
CPU_TYPE_I386 = 7

# Lion 10.7.5 i386 LaunchServices, inside
# _LSBundleDataGetUnsupportedFormatFlag:
#
#   cmpl   $0x01000007,%eax
#   jne    <unsupported>
#   testl  $0x14000000,%ebx
#   setne  %bl
#   jmp    <common-test>
#
# The controlled experiment changes only the x86_64-host mask from
# 0x14000000 to 0x16000000, adding the PPC architecture bit 0x02000000.
ORIGINAL = bytes(bytearray([
    0x3d, 0x07, 0x00, 0x00, 0x01,
    0x75, 0x1d,
    0xf7, 0xc3, 0x00, 0x00, 0x00, 0x14,
    0x0f, 0x95, 0xc3,
    0xeb, 0x30
]))
PATCHED = bytes(bytearray([
    0x3d, 0x07, 0x00, 0x00, 0x01,
    0x75, 0x1d,
    0xf7, 0xc3, 0x00, 0x00, 0x00, 0x16,
    0x0f, 0x95, 0xc3,
    0xeb, 0x30
]))


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def read_file(path):
    with open(path, "rb") as f:
        return f.read()


def write_file(path, data, mode):
    with open(path, "wb") as f:
        f.write(data)
    os.chmod(path, mode)


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


def count_occurrences(data, needle, start, size):
    region = data[start:start + size]
    positions = []
    pos = 0
    while True:
        idx = region.find(needle, pos)
        if idx < 0:
            break
        positions.append(start + idx)
        pos = idx + 1
    return positions


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

    if full_sha != EXPECTED_FULL_SHA256:
        print("error: input is not the validated Lion 10.7.5 LaunchServices binary", file=sys.stderr)
        print("expected_sha256=%s" % EXPECTED_FULL_SHA256, file=sys.stderr)
        return 68

    try:
        arch_off, arch_size, cpusubtype = parse_i386_range(data)
    except ValueError as e:
        print("error: %s" % e, file=sys.stderr)
        return 67

    print("i386_offset=0x%x" % arch_off)
    print("i386_size=%d" % arch_size)
    print("i386_cpusubtype=%d" % cpusubtype)
    print("i386_sha256=%s" % sha256_bytes(data[arch_off:arch_off + arch_size]))

    original_hits = count_occurrences(data, ORIGINAL, arch_off, arch_size)
    patched_hits = count_occurrences(data, PATCHED, arch_off, arch_size)
    print("original_signature_count=%d" % len(original_hits))
    print("patched_signature_count=%d" % len(patched_hits))

    if check_only:
        if len(original_hits) == 1 and len(patched_hits) == 0:
            print("RESULT: PATCHABLE")
            print("signature_file_offset=0x%x" % original_hits[0])
            return 0
        if len(original_hits) == 0 and len(patched_hits) == 1:
            print("RESULT: ALREADY_PATCHED")
            print("signature_file_offset=0x%x" % patched_hits[0])
            return 0
        print("RESULT: NOT_PATCHABLE")
        return 69

    if os.path.abspath(src) == os.path.abspath(dst):
        print("error: input and output must be different; system file is never patched in place", file=sys.stderr)
        return 64

    if len(original_hits) != 1 or len(patched_hits) != 0:
        print("error: exact patch signature is not unique in validated i386 slice", file=sys.stderr)
        return 69

    pos = original_hits[0]
    out = bytearray(data)
    out[pos:pos + len(ORIGINAL)] = bytearray(PATCHED)
    out = bytes(out)

    if len(out) != len(data):
        print("error: output size changed", file=sys.stderr)
        return 70

    # Only one byte is allowed to differ.
    diffs = [i for i, (a, b) in enumerate(zip(bytearray(data), bytearray(out))) if a != b]
    print("changed_byte_count=%d" % len(diffs))
    if len(diffs) != 1:
        print("error: expected exactly one changed byte", file=sys.stderr)
        return 70

    changed = diffs[0]
    print("changed_file_offset=0x%x" % changed)
    print("old_byte=0x%02x" % data[changed])
    print("new_byte=0x%02x" % out[changed])

    if changed != pos + 12 or data[changed] != b"\x14"[0] or out[changed] != b"\x16"[0]:
        print("error: unexpected patch delta", file=sys.stderr)
        return 70

    # Prove that bytes outside the i386 slice are unchanged.
    if out[:arch_off] != data[:arch_off] or out[arch_off + arch_size:] != data[arch_off + arch_size:]:
        print("error: data outside i386 slice changed", file=sys.stderr)
        return 70

    mode = stat.S_IMODE(os.stat(src).st_mode)
    write_file(dst, out, mode)

    verify = read_file(dst)
    verify_original = count_occurrences(verify, ORIGINAL, arch_off, arch_size)
    verify_patched = count_occurrences(verify, PATCHED, arch_off, arch_size)

    print("output=%s" % dst)
    print("output_size=%d" % len(verify))
    print("output_sha256=%s" % sha256_bytes(verify))
    print("output_i386_sha256=%s" % sha256_bytes(verify[arch_off:arch_off + arch_size]))
    print("output_original_signature_count=%d" % len(verify_original))
    print("output_patched_signature_count=%d" % len(verify_patched))

    if len(verify_original) != 0 or len(verify_patched) != 1:
        print("error: post-patch signature verification failed", file=sys.stderr)
        return 70

    print("RESULT: PASS")
    print("A private copy was patched. The input file was not modified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
