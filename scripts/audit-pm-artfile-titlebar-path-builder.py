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
COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

CREATE_PATH = "__ZN10CUIElement18CreateQSIImagePathElPK13CUIDescriptorPPK10__CFStringPhll"
APPEND_VARIANT = "__ZN7CUIPath19AppendWindowVariantEl"
APPEND_TITLEBAR_STATE = "__ZN7CUIPath31AppendWindowTitlebarButtonStateElll"

EXPECTED = {
    "10.6.8": {
        "build": "10K549",
        "arch": "ppc7400",
        "coreui_slice_sha256": "5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        "artfile_size": 5946480,
        "artfile_sha256": "1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        "branch_start": 0x28b00,
        "branch_end": 0x28d84,
        "semantic_ids": {
            "titlebarcontrols": 0xa6,
            "close": 0x13,
            "colorsryg": 0x16,
            "disabled": 0x1f,
            "minimize": 0x56,
            "regularwin": 0x7a,
            "zoom": 0xb6,
        },
        "branch_markers": [
            "li\tr4,0xa6",
            "li\tr4,0x13",
            "li\tr5,0x56",
            "li\tr5,0xb6",
            "li\tr4,0x16",
            "bl\t" + APPEND_VARIANT,
            "bl\t" + APPEND_TITLEBAR_STATE,
        ],
    },
    "10.7.5": {
        "build": "11G63",
        "arch": "i386",
        "coreui_slice_sha256": "5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        "artfile_size": 4765184,
        "artfile_sha256": "0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        "branch_start": 0x40bf8,
        "branch_end": 0x40dd4,
        "semantic_ids": {
            "titlebarcontrols": 0x99,
            "close": 0x14,
            "colorsryg": 0x17,
            "disabled": 0x22,
            "minimize": 0x55,
            "regularwin": 0x72,
            "zoom": 0xa9,
        },
        "branch_markers": [
            "$0x00000099",
            "$0x00000014",
            "$0x00000055",
            "$0x000000a9",
            "$0x00000017",
            "calll\t" + APPEND_VARIANT,
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


def symbol_rows(rows, symbols, target_name):
    index = None
    for i, item in enumerate(symbols):
        if item[1] == target_name:
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


def rows_in_range(rows, start, end):
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]


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
    end = min(len(data), off + limit)
    pos = off
    while pos < end:
        value = byte_value(data[pos])
        if value == 0:
            return "".join(out)
        if 0x20 <= value <= 0x7e:
            out.append(chr(value))
        else:
            out.append("\\x%02x" % value)
        pos += 1
    return "".join(out) + "<unterminated>"


def parse_dictionary(data):
    if len(data) < 24:
        return {}, None
    count = u16le(data, 4)
    table = u32le(data, 8)
    pool = u32le(data, 12)
    mapping = {}
    for ident in range(1, count + 1):
        entry = table + (ident - 1) * 8
        if entry + 8 > pool or entry + 8 > len(data):
            break
        rel = u32le(data, entry)
        text = cstring(data, pool + rel)
        if text is not None:
            mapping[text] = ident
    return mapping, {
        "count": count,
        "table": table,
        "pool": pool,
    }


def marker_present(text, marker):
    return marker in text


def immediate_forms(arch, ident):
    if arch == "ppc7400":
        return [
            ",0x%x" % ident,
            ",0x%02x" % ident,
        ]
    return [
        "$0x%08x" % ident,
        "$0x%x" % ident,
    ]


def helper_semantic_hits(body_text, arch, semantic_ids):
    hits = {}
    for name, ident in sorted(semantic_ids.items()):
        hits[name] = any(form in body_text for form in immediate_forms(arch, ident))
    return hits


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./pm-art-titlebar-path.txt"
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-art-titlebar-path.")

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip()
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip()
        expected = EXPECTED.get(product)

        if expected is None:
            issues.append("unsupported product version: %s" % product)
            arch = None
        else:
            arch = expected["arch"]
            if build != expected["build"]:
                issues.append("unexpected build version: %s" % build)

        art_data = ""
        art_size = -1
        art_sha = "MISSING"
        dictionary = {}
        header = None
        if os.path.isfile(ARTFILE):
            art_data = open(ARTFILE, "rb").read()
            art_size = len(art_data)
            art_sha = sha256(ARTFILE)
            dictionary, header = parse_dictionary(art_data)
        else:
            issues.append("ArtFile.bin missing")

        if expected is not None:
            if art_size != expected["artfile_size"]:
                issues.append("ArtFile.bin size mismatch")
            if art_sha != expected["artfile_sha256"]:
                issues.append("ArtFile.bin SHA mismatch")
            for name, ident in sorted(expected["semantic_ids"].items()):
                if dictionary.get(name) != ident:
                    issues.append(
                        "ArtFile semantic ID mismatch for %s: got %s expected 0x%x" %
                        (name,
                         ("0x%x" % dictionary.get(name)) if dictionary.get(name) is not None else "MISSING",
                         ident)
                    )

        slice_sha = "MISSING"
        symbols = []
        by_name = {}
        rows = []
        branch_rows = []
        helper_rows = {}

        if arch and os.path.isfile(COREUI):
            thin = os.path.join(tempdir, "CoreUI.%s" % arch)
            rc, out = run(["/usr/bin/lipo", COREUI, "-thin", arch, "-output", thin])
            if rc != 0:
                issues.append("CoreUI thin failed: %s" % out.strip())
            else:
                slice_sha = sha256(thin)
                if slice_sha != expected["coreui_slice_sha256"]:
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

                for name in [CREATE_PATH, APPEND_VARIANT, APPEND_TITLEBAR_STATE]:
                    if name not in by_name:
                        issues.append("missing CoreUI symbol: %s" % name)
                    else:
                        helper_rows[name] = symbol_rows(rows, symbols, name)

                branch_rows = rows_in_range(
                    rows, expected["branch_start"], expected["branch_end"]
                )
                branch_text = "\n".join(line for _, line in branch_rows)
                for marker in expected["branch_markers"]:
                    if not marker_present(branch_text, marker):
                        issues.append("titlebar branch marker missing: %s" % marker)
        else:
            if not os.path.isfile(COREUI):
                issues.append("CoreUI missing")

        with open(report, "w") as fp:
            write_line(fp, "== CoreUI titlebar ArtFile path-builder audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (arch if arch else "UNSUPPORTED"))
            write_line(fp, "coreui_path=%s" % COREUI)
            write_line(fp, "coreui_slice_sha256=%s" % slice_sha)
            write_line(fp, "artfile_path=%s" % ARTFILE)
            write_line(fp, "artfile_size=%d" % art_size)
            write_line(fp, "artfile_sha256=%s" % art_sha)

            write_line(fp)
            write_line(fp, "== Local ArtFile semantic IDs ==")
            if header is not None:
                write_line(fp, "component_count=%d" % header["count"])
                write_line(fp, "component_table_start=0x%x" % header["table"])
                write_line(fp, "component_string_pool_start=0x%x" % header["pool"])
            if expected is not None:
                for name in [
                    "titlebarcontrols", "close", "colorsryg", "disabled",
                    "minimize", "regularwin", "zoom"
                ]:
                    write_line(
                        fp,
                        "semantic=%s id=0x%02x" %
                        (name, dictionary.get(name, 0))
                    )

            write_line(fp)
            write_line(fp, "== CreateQSIImagePath titlebar branch ==")
            if expected is not None:
                write_line(fp, "range=0x%x..0x%x" %
                           (expected["branch_start"], expected["branch_end"]))
            for _, line in branch_rows:
                write_line(fp, line)

            for name in [APPEND_VARIANT, APPEND_TITLEBAR_STATE]:
                write_line(fp)
                write_line(fp, "== helper symbol: %s ==" % name)
                body = helper_rows.get(name, [])
                write_line(fp, "present=%s" % ("YES" if body else "NO"))
                if body:
                    write_line(fp, "symbol_address=0x%x" % by_name[name])
                    write_line(fp, "instruction_lines=%d" % len(body))
                    body_text = "\n".join(line for _, line in body)
                    hits = helper_semantic_hits(
                        body_text, arch, expected["semantic_ids"]
                    ) if expected is not None else {}
                    for semantic in [
                        "titlebarcontrols", "close", "colorsryg", "disabled",
                        "minimize", "regularwin", "zoom"
                    ]:
                        if semantic in hits:
                            write_line(
                                fp,
                                "semantic_immediate_%s=%s" %
                                (semantic, "YES" if hits[semantic] else "NO")
                            )
                    for _, line in body:
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
