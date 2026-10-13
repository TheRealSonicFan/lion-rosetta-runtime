#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import subprocess
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "titlebar-translated-path-feasibility-v1"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

EXPECTED = {
    "10.6.8": {
        "build": "10K549",
        "size": 5946480,
        "sha256": "1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        "record_count": 3324,
        "path_len": 8,
        "component_count": 182,
        "table_start": 0x18,
        "string_pool": 0x5c8,
        "index_start": 0xc4a,
        "payload_start": 0xa81c,
        "index_padding": 2,
    },
    "10.7.5": {
        "build": "11G63",
        "size": 4765184,
        "sha256": "0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        "record_count": 2674,
        "path_len": 8,
        "component_count": 169,
        "table_start": 0x18,
        "string_pool": 0x560,
        "index_start": 0xb9d,
        "payload_start": 0x88f8,
        "index_padding": 3,
    },
}

TARGETS = [
    (
        "clear",
        ("titlebarcontrols", "close", "colorsryg", "disabled", "regularwin"),
        (0xa6, 0x13, 0x16, 0x1f, 0x7a, 0x00, 0x00, 0x00),
    ),
    (
        "minus",
        ("titlebarcontrols", "colorsryg", "disabled", "minimize", "regularwin"),
        (0xa6, 0x16, 0x1f, 0x56, 0x7a, 0x00, 0x00, 0x00),
    ),
    (
        "zoom",
        ("titlebarcontrols", "colorsryg", "disabled", "regularwin", "zoom"),
        (0xa6, 0x16, 0x1f, 0x7a, 0xb6, 0x00, 0x00, 0x00),
    ),
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
            return None
        pos += 1
    return None


def hexbytes(data):
    return "".join("%02x" % bval(ch) for ch in data)


def bytes_from_ids(values):
    return "".join(chr(value) for value in values)


def parse_header(data):
    if len(data) < 24:
        return None
    return {
        "record_count": u16le(data, 0),
        "path_len": u16le(data, 2),
        "component_count": u16le(data, 4),
        "table_start": u32le(data, 8),
        "string_pool": u32le(data, 12),
        "index_start": u32le(data, 16),
        "payload_start": u32le(data, 20),
    }


def parse_dictionary(data, header):
    by_name = {}
    by_id = {}
    for ident in range(1, header["component_count"] + 1):
        entry = header["table_start"] + (ident - 1) * 8
        if entry + 8 > header["string_pool"] or entry + 8 > len(data):
            continue
        rel = u32le(data, entry)
        text = cstring(data, header["string_pool"] + rel)
        if text is not None:
            by_name[text] = ident
            by_id[ident] = text
    return by_name, by_id


def parse_index(data, header):
    record_size = header["path_len"] + 4
    records = []
    for index in range(header["record_count"]):
        off = header["index_start"] + index * record_size
        if off < 0 or off + record_size > len(data):
            break
        payload_rel = u32le(data, off)
        key = data[off + 4:off + record_size]
        records.append({
            "index": index,
            "off": off,
            "payload_rel": payload_rel,
            "payload_off": header["payload_start"] + payload_rel,
            "key": key,
        })
    return records


def decode_key(key, by_id):
    names = []
    invalid = []
    for ch in key:
        ident = bval(ch)
        if ident == 0:
            break
        name = by_id.get(ident)
        if name is None:
            invalid.append(ident)
            names.append("<invalid-0x%02x>" % ident)
        else:
            names.append(name)
    return tuple(names), invalid


def local_key_for_semantics(semantics, by_name, path_len):
    ids = []
    for name in semantics:
        ident = by_name.get(name)
        if ident is None:
            return None
        ids.append(ident)
    if len(ids) > path_len:
        return None
    ids += [0] * (path_len - len(ids))
    return bytes_from_ids(ids)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./pm-art-titlebar-translated-path-feasibility.txt"
    issues = []

    _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
    product = product_out.strip()
    _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
    build = build_out.strip()
    expected = EXPECTED.get(product)
    if expected is None:
        issues.append("unsupported product version: %s" % product)

    if not os.path.isfile(ARTFILE):
        issues.append("ArtFile.bin missing")
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
        issues.append("ArtFile header unavailable")
        header = dict(
            record_count=0, path_len=0, component_count=0,
            table_start=0, string_pool=0, index_start=0, payload_start=0
        )

    if expected is not None:
        for key in [
            "record_count", "path_len", "component_count", "table_start",
            "string_pool", "index_start", "payload_start"
        ]:
            if header[key] != expected[key]:
                issues.append(
                    "header %s mismatch: got 0x%x expected 0x%x" %
                    (key, header[key], expected[key])
                )

    record_size = header["path_len"] + 4
    index_end = header["index_start"] + header["record_count"] * record_size
    index_padding = header["payload_start"] - index_end
    if index_end > header["payload_start"]:
        issues.append("path index overlaps payload region")
    if expected is not None and index_padding != expected["index_padding"]:
        issues.append(
            "path index padding mismatch: got %d expected %d" %
            (index_padding, expected["index_padding"])
        )

    by_name, by_id = parse_dictionary(data, header)
    records = parse_index(data, header)
    if len(records) != header["record_count"]:
        issues.append(
            "path index record count mismatch: parsed %d expected %d" %
            (len(records), header["record_count"])
        )

    target_results = []
    for label, semantics, snow_ids in TARGETS:
        local_key = local_key_for_semantics(semantics, by_name, header["path_len"])
        direct_hits = []
        set_hits = []
        source_hits = []
        if local_key is not None:
            for record in records:
                decoded, invalid = decode_key(record["key"], by_id)
                if record["key"] == local_key:
                    direct_hits.append(record)
                if not invalid and sorted(decoded) == sorted(semantics):
                    set_hits.append((record, decoded))
                if record["key"] == bytes_from_ids(snow_ids):
                    source_hits.append(record)

        payloads_valid = True
        for record in direct_hits:
            if record["payload_off"] < 0 or record["payload_off"] + 0x68 > len(data):
                payloads_valid = False

        if local_key is None:
            disposition = "MISSING_LOCAL_COMPONENT"
        elif direct_hits:
            disposition = "DIRECT_INDEX_HIT"
        elif set_hits:
            disposition = "SEMANTIC_SET_REORDERED"
        else:
            disposition = "SEMANTIC_PATH_MISSING"

        target_results.append({
            "label": label,
            "semantics": semantics,
            "snow_key": bytes_from_ids(snow_ids),
            "local_key": local_key,
            "direct_hits": direct_hits,
            "set_hits": set_hits,
            "source_hits": source_hits,
            "payloads_valid": payloads_valid,
            "disposition": disposition,
        })

    source_control = "NA"
    translated_feasibility = "NA"
    if product == "10.6.8":
        source_control = "PASS" if all(
            item["disposition"] == "DIRECT_INDEX_HIT" and item["payloads_valid"]
            for item in target_results
        ) else "FAIL"
    elif product == "10.7.5":
        translated_feasibility = "PASS" if all(
            item["disposition"] == "DIRECT_INDEX_HIT" and item["payloads_valid"]
            for item in target_results
        ) else "FAIL"

    with open(report, "w") as fp:
        write_line(fp, "== CoreUI titlebar translated-path ArtFile feasibility audit ==")
        write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
        write_line(fp, "product_version=%s" % product)
        write_line(fp, "build_version=%s" % build)
        write_line(fp, "artfile_size=%d" % art_size)
        write_line(fp, "artfile_sha256=%s" % art_sha)

        write_line(fp)
        write_line(fp, "== Legacy ArtFile lookup index ==")
        write_line(fp, "record_count=%d" % header["record_count"])
        write_line(fp, "path_length=%d" % header["path_len"])
        write_line(fp, "record_size=%d" % record_size)
        write_line(fp, "component_count=%d" % header["component_count"])
        write_line(fp, "component_table_start=0x%x" % header["table_start"])
        write_line(fp, "component_string_pool_start=0x%x" % header["string_pool"])
        write_line(fp, "path_index_start=0x%x" % header["index_start"])
        write_line(fp, "path_index_end=0x%x" % index_end)
        write_line(fp, "payload_region_start=0x%x" % header["payload_start"])
        write_line(fp, "path_index_padding=%d" % index_padding)
        write_line(fp, "parsed_path_records=%d" % len(records))
        write_line(fp, "lookup_record_layout=le32_payload_relative_offset + 8_byte_component_path")
        write_line(fp, "payload_address_formula=payload_region_start + payload_relative_offset")

        write_line(fp)
        write_line(fp, "== Exact crash-time titlebar semantic paths ==")
        for item in target_results:
            write_line(fp, "path=%s" % item["label"])
            write_line(fp, "semantic_path=%s" % ".".join(item["semantics"]))
            write_line(fp, "snow_key=%s" % hexbytes(item["snow_key"]))
            write_line(
                fp,
                "local_semantic_key=%s" %
                (hexbytes(item["local_key"]) if item["local_key"] is not None else "UNRESOLVED")
            )
            write_line(fp, "untranslated_snow_key_index_hits=%d" % len(item["source_hits"]))
            write_line(fp, "local_semantic_key_index_hits=%d" % len(item["direct_hits"]))
            write_line(fp, "semantic_component_set_index_hits=%d" % len(item["set_hits"]))
            write_line(fp, "disposition=%s" % item["disposition"])
            for record in item["direct_hits"][:16]:
                write_line(
                    fp,
                    "direct_hit index=%d record_off=0x%x payload_rel=0x%x payload_off=0x%x payload_0x68_in_file=%s" %
                    (
                        record["index"], record["off"], record["payload_rel"],
                        record["payload_off"],
                        "YES" if (
                            record["payload_off"] >= 0 and
                            record["payload_off"] + 0x68 <= len(data)
                        ) else "NO",
                    )
                )
            for record, decoded in item["set_hits"][:16]:
                if item["local_key"] is not None and record["key"] == item["local_key"]:
                    continue
                write_line(
                    fp,
                    "semantic_set_hit index=%d key=%s decoded=%s payload_off=0x%x" %
                    (
                        record["index"], hexbytes(record["key"]),
                        ".".join(decoded), record["payload_off"]
                    )
                )
            write_line(fp)

        write_line(fp, "source_archive_positive_control=%s" % source_control)
        write_line(fp, "lion_translated_path_feasibility=%s" % translated_feasibility)

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
        write_line(fp, "The analyzer opened only local ArtFile.bin for reading.")
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
