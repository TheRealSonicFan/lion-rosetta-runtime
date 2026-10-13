#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "titlebar-state-transition-v1"
COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

CREATE_PATH = "__ZN10CUIElement18CreateQSIImagePathElPK13CUIDescriptorPPK10__CFStringPhll"
APPEND_STATE = "__ZN7CUIPath11AppendStateElhi"
APPEND_TITLEBAR_STATE = "__ZN7CUIPath31AppendWindowTitlebarButtonStateElll"

EXPECTED = {
    "10.6.8": {
        "build": "10K549",
        "arch": "ppc7400",
        "coreui_sha256": "5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        "artfile_size": 5946480,
        "artfile_sha256": "1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        "prologue_range": (0x25cbc, 0x25d40),
        "branch_range": (0x28b00, 0x28d84),
        "continuation_range": (0x28e78, 0x28ec0),
        "primary_selectors": range(0xa3, 0xab),
        "variant_selectors": [("regularwin", 0), ("variant1", 0x14c), ("variant2", 0x14d)],
        "required_markers": [
            "or\tr28,r8,r8",
            "lwz\tr28,0x18(r27)",
            "li\tr28,0xa3",
            "lwz\tr29,0x1c(r27)",
            "li\tr5,0xab",
            "bl\t" + APPEND_STATE,
        ],
    },
    "10.7.5": {
        "build": "11G63",
        "arch": "i386",
        "coreui_sha256": "5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        "artfile_size": 4765184,
        "artfile_sha256": "0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        "prologue_range": (0x3d39a, 0x3d413),
        "branch_range": (0x40bf8, 0x40dd4),
        "helper_address": 0x41a8e,
        "pic_base": 0x41aee,
        "special_table_address": 0x41bb8,
        "regular_table_address": 0x41bd8,
        "primary_selectors": range(0xad, 0xb5),
        "secondary_selectors": [("other", 0), ("key", 0xb7), ("active", 0xb8), ("inactive", 0xb9)],
        "variant_selectors": [("regularwin", 0), ("variant1", 0x175), ("variant2", 0x176)],
        "required_markers": [
            "movl\t0x1c(%ebp),%eax",
            "movl\t0x28(%eax),%eax",
            "movl\t$0x000000ad,0xcc(%ebp)",
            "movl\t0x2c(%ecx),%ecx",
            "movl\t0x30(%eax),%eax",
            "calll\t" + APPEND_TITLEBAR_STATE,
        ],
    },
}


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha256(path):
    h = hashlib.sha256()
    fp = open(path, "rb")
    try:
        while True:
            data = fp.read(1024 * 1024)
            if not data:
                break
            h.update(data)
    finally:
        fp.close()
    return h.hexdigest()


def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def parse_hex_token(token):
    token = token.rstrip(":")
    if token.startswith("0x") or token.startswith("0X"):
        token = token[2:]
    if not token:
        return None
    for ch in token:
        if ch not in "0123456789abcdefABCDEF":
            return None
    try:
        return int(token, 16)
    except ValueError:
        return None


def parse_symbols(text):
    ordered = []
    by_name = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None or "(__TEXT,__text)" not in line:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        if name not in by_name:
            by_name[name] = addr
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, line))
    return rows


def rows_in_range(rows, start, end):
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]


def symbol_rows(rows, symbols, name):
    index = None
    for i, item in enumerate(symbols):
        if item[1] == name:
            index = i
            break
    if index is None:
        return []
    start = symbols[index][0]
    end = symbols[index + 1][0] if index + 1 < len(symbols) else None
    out = []
    for addr, line in rows:
        if addr < start:
            continue
        if end is not None and addr >= end:
            break
        out.append((addr, line))
    return out


def u16le(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32le(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def byte_value(ch):
    if isinstance(ch, int):
        return ch
    return ord(ch)


def cstring(data, off, limit=256):
    if off < 0 or off >= len(data):
        return None
    out = []
    pos = off
    end = min(len(data), off + limit)
    while pos < end:
        value = byte_value(data[pos])
        if value == 0:
            return "".join(out)
        if 0x20 <= value <= 0x7e:
            out.append(chr(value))
        else:
            return None
        pos += 1
    return None


def parse_dictionary(data):
    mapping = {}
    reverse = {}
    if len(data) < 24:
        return mapping, reverse
    count = u16le(data, 4)
    table = u32le(data, 8)
    pool = u32le(data, 12)
    for ident in range(1, count + 1):
        entry = table + (ident - 1) * 8
        if entry + 8 > pool or entry + 8 > len(data):
            break
        rel = u32le(data, entry)
        text = cstring(data, pool + rel)
        if text is not None:
            mapping[text] = ident
            reverse[ident] = text
    return mapping, reverse


def macho_vm_read(path, vmaddr, size):
    data = open(path, "rb").read()
    if len(data) < 28:
        raise ValueError("thin Mach-O too small")
    magic_le = struct.unpack("<I", data[0:4])[0]
    magic_be = struct.unpack(">I", data[0:4])[0]
    if magic_le == 0xfeedface:
        endian = "<"
    elif magic_be == 0xfeedface:
        endian = ">"
    else:
        raise ValueError("unsupported Mach-O magic")
    header = struct.unpack(endian + "7I", data[0:28])
    ncmds = header[4]
    off = 28
    for _ in range(ncmds):
        if off + 8 > len(data):
            raise ValueError("truncated load commands")
        cmd, cmdsize = struct.unpack(endian + "2I", data[off:off + 8])
        if cmdsize < 8 or off + cmdsize > len(data):
            raise ValueError("invalid load command")
        if cmd == 0x1 and cmdsize >= 56:
            seg = struct.unpack(endian + "2I16s8I", data[off:off + 56])
            seg_vmaddr = seg[3]
            seg_vmsize = seg[4]
            seg_fileoff = seg[5]
            seg_filesize = seg[6]
            if vmaddr >= seg_vmaddr and vmaddr + size <= seg_vmaddr + seg_vmsize:
                delta = vmaddr - seg_vmaddr
                if delta + size > seg_filesize:
                    raise ValueError("requested vm range is not file-backed")
                fileoff = seg_fileoff + delta
                return data[fileoff:fileoff + size], endian
        off += cmdsize
    raise ValueError("vm address not mapped in Mach-O")


def snow_append_state(primary):
    mask = 0xab
    fallback = "active"
    table = {
        0xa3: (0x01, "active"),
        0xa4: (0x02, "disabled"),
        0xa5: (0x04, "drag"),
        0xa6: (0x08, "inactive"),
        0xa7: (0x10, "key"),
        0xa8: (0x20, "pressed"),
        0xa9: (0x40, "pulsed"),
        0xaa: (0x80, "rollover"),
    }
    if primary == 0:
        primary = 0xa3
    item = table.get(primary)
    if item is None:
        return fallback
    bit, semantic = item
    if mask & bit:
        return semantic
    return fallback


def snow_titlebar_state(variant, primary):
    if variant in (0x14c, 0x14d):
        if primary == 0xa6:
            return "active"
        if primary == 0xa3:
            return "key"
    return snow_append_state(primary)


def decode_lion_tables(thin):
    special_raw, endian = macho_vm_read(thin, 0x41bb8, 8 * 4)
    regular_raw, endian2 = macho_vm_read(thin, 0x41bd8, 7 * 4)
    if endian != "<" or endian2 != "<":
        raise ValueError("Lion i386 helper tables are not little-endian")
    special_targets = []
    regular_targets = []
    for i in range(8):
        rel = struct.unpack("<i", special_raw[i * 4:i * 4 + 4])[0]
        special_targets.append(0x41aee + rel)
    for i in range(7):
        rel = struct.unpack("<i", regular_raw[i * 4:i * 4 + 4])[0]
        regular_targets.append(0x41aee + rel)
    return special_targets, regular_targets


def lion_target_semantic(target):
    mapping = {
        0x41b05: "active",
        0x41b27: "key",
        0x41b4a: "rollover",
        0x41b4c: "active",
        0x41b9a: "disabled",
        0x41b9e: "inactive",
        0x41ba2: "pressed",
        0x41ba6: "inactive",
    }
    return mapping.get(target, "UNKNOWN")


def lion_titlebar_state(variant, primary, secondary, special_table, regular_table):
    if primary == 0xb4:
        return "rollover"
    if primary == 0xb2:
        return "pressed"
    if primary == 0xae and secondary != 0xb9:
        return "disabled"

    special = variant in (0x175, 0x176)
    if special:
        if secondary == 0xb8:
            return "active"
        if secondary == 0xb9:
            return "inactive"
        if secondary == 0xb7:
            return "key"
        index = primary - 0xad
        if 0 <= index < len(special_table):
            return special_table[index]
        return "active"

    if secondary == 0xb8:
        return "activenokey"
    if secondary == 0xb9:
        return "inactive"
    if secondary == 0xb7:
        return "active"
    index = primary - 0xae
    if 0 <= index < len(regular_table):
        return regular_table[index]
    return "active"


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./pm-art-titlebar-state-transition.txt"
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-art-titlebar-transition.")
    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip()
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip()
        expected = EXPECTED.get(product)
        if expected is None:
            issues.append("unsupported product version: %s" % product)
            expected = {}
        elif build != expected["build"]:
            issues.append("unexpected build version: %s" % build)

        art_size = -1
        art_sha = "MISSING"
        dictionary = {}
        reverse_dictionary = {}
        if os.path.isfile(ARTFILE):
            art_data = open(ARTFILE, "rb").read()
            art_size = len(art_data)
            art_sha = sha256(ARTFILE)
            dictionary, reverse_dictionary = parse_dictionary(art_data)
        else:
            issues.append("ArtFile.bin missing")

        arch = expected.get("arch")
        slice_sha = "MISSING"
        rows = []
        symbols = []
        by_name = {}
        prologue_rows = []
        branch_rows = []
        helper_rows = []
        special_targets = []
        regular_targets = []
        special_semantics = []
        regular_semantics = []

        if expected:
            if art_size != expected["artfile_size"]:
                issues.append("ArtFile.bin size mismatch")
            if art_sha != expected["artfile_sha256"]:
                issues.append("ArtFile.bin SHA mismatch")

        if arch and os.path.isfile(COREUI):
            thin = os.path.join(tempdir, "CoreUI.%s" % arch)
            rc, out = run(["/usr/bin/lipo", COREUI, "-thin", arch, "-output", thin])
            if rc != 0:
                issues.append("CoreUI thin failed: %s" % out.strip())
            else:
                slice_sha = sha256(thin)
                if slice_sha != expected["coreui_sha256"]:
                    issues.append("CoreUI slice SHA mismatch")
                rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                if rc != 0:
                    issues.append("CoreUI nm failed")
                else:
                    symbols, by_name = parse_symbols(nm_out)
                rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                if rc != 0:
                    issues.append("CoreUI disassembly failed")
                else:
                    rows = parse_instructions(dis_out)

                if CREATE_PATH not in by_name:
                    issues.append("missing CoreUI symbol: %s" % CREATE_PATH)
                prologue_rows = rows_in_range(rows, expected["prologue_range"][0], expected["prologue_range"][1])
                branch_rows = rows_in_range(rows, expected["branch_range"][0], expected["branch_range"][1])
                validation_text = "\n".join(line for _, line in prologue_rows + branch_rows)
                if product == "10.6.8":
                    validation_text += "\n" + "\n".join(
                        line for _, line in rows_in_range(rows, expected["continuation_range"][0], expected["continuation_range"][1])
                    )
                    if APPEND_STATE not in by_name:
                        issues.append("missing CoreUI symbol: %s" % APPEND_STATE)
                    helper_rows = symbol_rows(rows, symbols, APPEND_STATE)
                    validation_text += "\n" + "\n".join(line for _, line in helper_rows)
                else:
                    if APPEND_TITLEBAR_STATE not in by_name:
                        issues.append("missing CoreUI symbol: %s" % APPEND_TITLEBAR_STATE)
                    else:
                        helper_rows = symbol_rows(rows, symbols, APPEND_TITLEBAR_STATE)
                    validation_text += "\n" + "\n".join(line for _, line in helper_rows)
                for marker in expected["required_markers"]:
                    if marker not in validation_text:
                        issues.append("required transition marker missing: %s" % marker)

                if product == "10.7.5" and APPEND_TITLEBAR_STATE in by_name:
                    if by_name[APPEND_TITLEBAR_STATE] != expected["helper_address"]:
                        issues.append("unexpected Lion titlebar helper address")
                    try:
                        special_targets, regular_targets = decode_lion_tables(thin)
                        special_semantics = [lion_target_semantic(x) for x in special_targets]
                        regular_semantics = [lion_target_semantic(x) for x in regular_targets]
                        for semantic in special_semantics + regular_semantics:
                            if semantic == "UNKNOWN":
                                issues.append("unclassified Lion titlebar jump-table target")
                                break
                    except Exception as exc:
                        issues.append("Lion titlebar jump-table decode failed: %s" % exc)
        else:
            if not os.path.isfile(COREUI):
                issues.append("CoreUI missing")

        with open(report, "w") as fp:
            write_line(fp, "== CoreUI titlebar state transition/provenance audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (arch if arch else "UNSUPPORTED"))
            write_line(fp, "coreui_slice_sha256=%s" % slice_sha)
            write_line(fp, "artfile_size=%d" % art_size)
            write_line(fp, "artfile_sha256=%s" % art_sha)

            write_line(fp)
            write_line(fp, "== State input provenance ==")
            if product == "10.6.8":
                write_line(fp, "primary_source=arg5-or-descriptor+0x18")
                write_line(fp, "primary_default=0xa3")
                write_line(fp, "secondary_source=arg6-or-descriptor+0x1c")
                write_line(fp, "titlebar_secondary_used=NO")
            elif product == "10.7.5":
                write_line(fp, "primary_source=arg5-or-descriptor+0x28")
                write_line(fp, "primary_default=0xad")
                write_line(fp, "secondary_source=arg6-or-descriptor+0x30")
                write_line(fp, "titlebar_secondary_source=descriptor+0x2c")
                write_line(fp, "titlebar_secondary_used=YES")
            for _, line in prologue_rows:
                write_line(fp, line)

            write_line(fp)
            write_line(fp, "== State transition table ==")
            if product == "10.6.8":
                for variant_name, variant_value in expected.get("variant_selectors", []):
                    for primary in expected.get("primary_selectors", []):
                        semantic = snow_titlebar_state(variant_value, primary)
                        ident = dictionary.get(semantic)
                        write_line(
                            fp,
                            "variant=%s raw_variant=0x%x primary=0x%x secondary=UNUSED output=%s output_id=%s" %
                            (variant_name, variant_value, primary, semantic,
                             ("0x%02x" % ident) if ident is not None else "MISSING")
                        )
                        if ident is None:
                            issues.append("Snow transition output missing from ArtFile: %s" % semantic)
            elif product == "10.7.5":
                write_line(fp, "special_jump_table_address=0x41bb8")
                for i, target in enumerate(special_targets):
                    primary = 0xad + i
                    semantic = special_semantics[i] if i < len(special_semantics) else "UNKNOWN"
                    write_line(fp, "special_jump primary=0x%x target=0x%x semantic=%s" % (primary, target, semantic))
                write_line(fp, "regular_jump_table_address=0x41bd8")
                for i, target in enumerate(regular_targets):
                    primary = 0xae + i
                    semantic = regular_semantics[i] if i < len(regular_semantics) else "UNKNOWN"
                    write_line(fp, "regular_jump primary=0x%x target=0x%x semantic=%s" % (primary, target, semantic))
                for variant_name, variant_value in expected.get("variant_selectors", []):
                    for secondary_name, secondary in expected.get("secondary_selectors", []):
                        for primary in expected.get("primary_selectors", []):
                            semantic = lion_titlebar_state(
                                variant_value, primary, secondary,
                                special_semantics, regular_semantics
                            )
                            ident = dictionary.get(semantic)
                            write_line(
                                fp,
                                "variant=%s raw_variant=0x%x primary=0x%x secondary=%s raw_secondary=0x%x output=%s output_id=%s" %
                                (variant_name, variant_value, primary, secondary_name, secondary,
                                 semantic, ("0x%02x" % ident) if ident is not None else "MISSING")
                            )
                            if semantic == "UNKNOWN" or ident is None:
                                issues.append("Lion transition output unresolved")

            write_line(fp)
            write_line(fp, "== Helper disassembly ==")
            for _, line in helper_rows:
                write_line(fp, line)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "The analyzer opened only local CoreUI and ArtFile.bin for reading.")
            write_line(fp, "A temporary architecture slice was created only under the system temporary directory and removed on exit.")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No process was attached.")
            write_line(fp, "No framework, resource, Rosetta cache, service, or XNU state was modified.")

        print("Created: %s" % report)
        if issues:
            print("RESULT: FAIL")
            for issue in issues:
                print("validation_issue=%s" % issue)
            return 1
        print("RESULT: PASS")
        return 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
