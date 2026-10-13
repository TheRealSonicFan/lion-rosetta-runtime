#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import subprocess
import sys

ANALYZER_VERSION = "1"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

EXPECTED = {
    "10.6.8": {
        "build": "10K549",
        "size": 5946480,
        "sha256": "1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        "component_count": 182,
    },
    "10.7.5": {
        "build": "11G63",
        "size": 4765184,
        "sha256": "0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        "component_count": 169,
    },
}

PATHS = [
    ("clear", [0xa6, 0x13, 0x16, 0x1f, 0x7a, 0x00, 0x00, 0x00]),
    ("minus", [0xa6, 0x16, 0x1f, 0x56, 0x7a, 0x00, 0x00, 0x00]),
    ("b6", [0xa6, 0x16, 0x1f, 0x7a, 0xb6, 0x00, 0x00, 0x00]),
]


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


def bval(ch):
    if isinstance(ch, int):
        return ch
    return ord(ch)


def u16le(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32le(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def cstring(data, off, limit=512):
    if off < 0 or off >= len(data):
        return None
    out = []
    end = min(len(data), off + limit)
    pos = off
    while pos < end:
        value = bval(data[pos])
        if value == 0:
            return "".join(out)
        if 0x20 <= value <= 0x7e:
            out.append(chr(value))
        else:
            out.append("\\x%02x" % value)
        pos += 1
    return "".join(out) + "<unterminated>"


def parse_header(data):
    if len(data) < 24:
        return None
    return {
        "u16_0": u16le(data, 0),
        "path_len": u16le(data, 2),
        "component_count": u16le(data, 4),
        "table_start": u32le(data, 8),
        "string_pool": u32le(data, 12),
        "field10": u32le(data, 16),
        "field14": u32le(data, 20),
    }


def component_row(data, header, ident):
    count = header["component_count"]
    row = {
        "id": ident,
        "valid_id": ident >= 1 and ident <= count,
        "entry_off": None,
        "word0": None,
        "word1": None,
        "string_off": None,
        "text": None,
        "entry_in_table": False,
        "string_in_file": False,
    }
    if not row["valid_id"]:
        return row

    entry_off = header["table_start"] + (ident - 1) * 8
    row["entry_off"] = entry_off
    row["entry_in_table"] = (
        entry_off >= header["table_start"] and
        entry_off + 8 <= header["string_pool"]
    )
    if entry_off < 0 or entry_off + 8 > len(data):
        return row

    word0 = u32le(data, entry_off)
    word1 = u32le(data, entry_off + 4)
    string_off = header["string_pool"] + word0
    row["word0"] = word0
    row["word1"] = word1
    row["string_off"] = string_off
    row["string_in_file"] = 0 <= string_off < len(data)
    if row["entry_in_table"] and row["string_in_file"]:
        row["text"] = cstring(data, string_off)
    return row


def path_hex(values):
    return "".join("%02x" % value for value in values)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./pm-art-components.txt"
    issues = []

    _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
    product = product_out.strip()
    _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
    build = build_out.strip()

    expected = EXPECTED.get(product)
    if expected is None:
        issues.append("unsupported product version: %s" % product)

    if not os.path.isfile(ARTFILE):
        issues.append("ArtFile.bin missing: %s" % ARTFILE)
        data = ""
        art_size = -1
        art_sha = "MISSING"
    else:
        data = open(ARTFILE, "rb").read()
        art_size = len(data)
        art_sha = sha256(ARTFILE)

    if expected is not None:
        if build != expected["build"]:
            issues.append("unexpected build version: %s" % build)
        if art_size != expected["size"]:
            issues.append("ArtFile.bin size mismatch")
        if art_sha != expected["sha256"]:
            issues.append("ArtFile.bin SHA mismatch")

    header = parse_header(data)
    if header is None:
        issues.append("ArtFile.bin header unavailable")
        header = {
            "u16_0": 0,
            "path_len": 0,
            "component_count": 0,
            "table_start": 0,
            "string_pool": 0,
            "field10": 0,
            "field14": 0,
        }

    if expected is not None and header["component_count"] != expected["component_count"]:
        issues.append("component count mismatch")

    table_end = header["table_start"] + header["component_count"] * 8
    table_exact = bool(header["component_count"] and table_end == header["string_pool"])
    if not table_exact:
        issues.append("component table does not end at string pool")

    rows = []
    for ident in range(1, header["component_count"] + 1):
        row = component_row(data, header, ident)
        rows.append(row)
        if not row["entry_in_table"]:
            issues.append("component 0x%02x entry outside table" % ident)
        if not row["string_in_file"]:
            issues.append("component 0x%02x string outside file" % ident)
        if row["text"] is None:
            issues.append("component 0x%02x string unresolved" % ident)

    digest = hashlib.sha256()
    for row in rows:
        line = "%02x\t%08x\t%08x\t%s\n" % (
            row["id"],
            row["word0"] if row["word0"] is not None else 0xffffffff,
            row["word1"] if row["word1"] is not None else 0xffffffff,
            row["text"] if row["text"] is not None else "UNRESOLVED",
        )
        if not isinstance(line, bytes):
            line = line.encode("utf-8")
        digest.update(line)

    with open(report, "w") as fp:
        write_line(fp, "== CoreUI ArtFile component dictionary audit ==")
        write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        write_line(fp, "product_version=%s" % product)
        write_line(fp, "build_version=%s" % build)
        write_line(fp, "artfile_path=%s" % ARTFILE)
        write_line(fp, "artfile_size=%d" % art_size)
        write_line(fp, "artfile_sha256=%s" % art_sha)

        write_line(fp)
        write_line(fp, "== Legacy ArtFile header ==")
        write_line(fp, "header_u16_0=%d" % header["u16_0"])
        write_line(fp, "path_length=%d" % header["path_len"])
        write_line(fp, "component_count=%d" % header["component_count"])
        write_line(fp, "component_count_hex=0x%x" % header["component_count"])
        write_line(fp, "component_table_start=0x%x" % header["table_start"])
        write_line(fp, "component_table_end=0x%x" % table_end)
        write_line(fp, "component_string_pool_start=0x%x" % header["string_pool"])
        write_line(fp, "component_table_end_matches_string_pool=%s" %
                   ("YES" if table_exact else "NO"))
        write_line(fp, "header_field10=%d" % header["field10"])
        write_line(fp, "header_field14=%d" % header["field14"])
        write_line(fp, "component_dictionary_sha256=%s" % digest.hexdigest())

        write_line(fp)
        write_line(fp, "== Observed invalid-path component IDs ==")
        for ident in [0x13, 0x16, 0x1f, 0x56, 0x7a, 0xa6, 0xb6]:
            row = component_row(data, header, ident)
            write_line(
                fp,
                "component_id=0x%02x valid=%s entry_off=%s word0=%s word1=%s "
                "string_off=%s text=%s" %
                (
                    ident,
                    "YES" if row["valid_id"] else "NO",
                    "0x%x" % row["entry_off"] if row["entry_off"] is not None else "OUT_OF_RANGE",
                    "0x%08x" % row["word0"] if row["word0"] is not None else "OUT_OF_RANGE",
                    "0x%08x" % row["word1"] if row["word1"] is not None else "OUT_OF_RANGE",
                    "0x%x" % row["string_off"] if row["string_off"] is not None else "OUT_OF_RANGE",
                    row["text"] if row["text"] is not None else "OUT_OF_RANGE",
                )
            )

        write_line(fp)
        write_line(fp, "== Observed path decode ==")
        path_validity = {}
        for label, values in PATHS:
            names = []
            invalid_ids = []
            for ident in values:
                if ident == 0:
                    break
                row = component_row(data, header, ident)
                if row["valid_id"] and row["entry_in_table"] and row["text"] is not None:
                    names.append(row["text"])
                else:
                    invalid_ids.append(ident)
                    names.append("<invalid-0x%02x>" % ident)
            all_valid = not invalid_ids
            path_validity[label] = all_valid
            write_line(
                fp,
                "path=%s bytes=%s all_components_valid=%s invalid_ids=%s decoded=%s" %
                (
                    label,
                    path_hex(values),
                    "YES" if all_valid else "NO",
                    ",".join("0x%02x" % value for value in invalid_ids)
                    if invalid_ids else "NONE",
                    ".".join(names),
                )
            )

        expected_shape = False
        if product == "10.6.8":
            expected_shape = (
                path_validity.get("clear") is True and
                path_validity.get("minus") is True and
                path_validity.get("b6") is True
            )
        elif product == "10.7.5":
            expected_shape = (
                path_validity.get("clear") is True and
                path_validity.get("minus") is True and
                path_validity.get("b6") is False
            )
        write_line(fp, "release_expected_path_validity=%s" %
                   ("PASS" if expected_shape else "FAIL"))
        if expected is not None and not expected_shape:
            issues.append("observed path validity does not match release boundary")

        write_line(fp)
        write_line(fp, "== Complete component dictionary ==")
        for row in rows:
            write_line(
                fp,
                "id=0x%02x entry_off=0x%x word0=0x%08x word1=0x%08x "
                "string_off=0x%x text=%s" %
                (
                    row["id"],
                    row["entry_off"],
                    row["word0"],
                    row["word1"],
                    row["string_off"],
                    row["text"],
                )
            )

        write_line(fp)
        write_line(fp, "== Tail component dictionary ==")
        tail_start = 0xa0
        for ident in range(tail_start, header["component_count"] + 1):
            row = component_row(data, header, ident)
            write_line(
                fp,
                "id=0x%02x entry_off=0x%x text=%s" %
                (ident, row["entry_off"], row["text"])
            )

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
        write_line(fp, "The analyzer opened only the local CoreUI ArtFile.bin for reading.")
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


if __name__ == "__main__":
    sys.exit(main())
