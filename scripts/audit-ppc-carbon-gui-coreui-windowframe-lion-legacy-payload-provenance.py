#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import subprocess
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-lion-legacy-payload-provenance-v1"

RESOURCES = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources"
SARTFILE = os.path.join(RESOURCES, "SArtFile.bin")
ARTFILE10 = os.path.join(RESOURCES, "ArtFile.bin")
ARTFILE20 = os.path.join(RESOURCES, "ArtFile200.bin")

EXPECTED_PRODUCT = "10.7.5"
EXPECTED_BUILD = "11G63"

EXPECTED_FILES = {
    "SArtFile": dict(
        path=SARTFILE,
        size=9370228,
        sha="29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b",
    ),
    "ArtFile10": dict(
        path=ARTFILE10,
        size=4765184,
        sha="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
    ),
    "ArtFile20": dict(
        path=ARTFILE20,
        size=18101720,
        sha="463bdec2bb3a3f66d35bc85e80129b8e0ea85e474e8725b093d747ffa687614f",
    ),
}

# Exact five provider fingerprints recovered from the accepted Snow 10.6.8
# live-active SArtFile payload report.
TARGETS = [
    ("0x4e8e", "44897e71f9f949fa7b276adc71a2d58c02ebaab80721ac0035d113fd9f37288f"),
    ("0x4e90", "ba825c44fbcb9a52febacfdd60c29383b3a9fb83d3740789f434e28b1cbf1cd7"),
    ("0x4e8d", "9577c7876e34e40a778511795c7a28702af3613dca28b5edeac5f6972ff9912e"),
    ("0x4e8f", "9f7b4499af15c5d4f3156650ff12c3042d084e49cee2ef911b3ba72183d912fa"),
    ("0x4e91", "b7f2dd24cc33a63a3b8a05f629f4289f0eaa130a7cc61b2dbc56d45c767d5385"),
]
TARGET_BY_HASH = dict((digest, source_id) for source_id, digest in TARGETS)

EXPECTED_SART_MATCHES = {
    "0x4e8e": "0x4e76",
    "0x4e90": "0x4e78",
    "0x4e8d": "0x4e75",
}
EXPECTED_SART_UNMATCHED = set(["0x4e8f", "0x4e91"])

SART_ID_BASE = 0x4e20
SART_TABLE_BASE = 0x08
SART_TABLE_STRIDE = 4
SART_SLOT_STRIDE = 0x0c
SART_WIDTH_OFF = 0x0c
SART_HEIGHT_OFF = 0x0e
SART_LENGTH_OFF = 0x10
SART_DATA_OFF = 0x14

ART_HEADER_SIZE = 24
ART_RECORD_HEADER_SIZE = 0x68
ART_CELL_OFFSET_BASE = 0x20
ART_CELL_WIDTH_BASE = 0x44
ART_CELL_HEIGHT_BASE = 0x56
ART_MAX_CELLS = 9
TARGET_BYTES = 484


def u16(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha_file(path):
    h = hashlib.sha256()
    fp = open(path, "rb")
    try:
        while True:
            block = fp.read(1024 * 1024)
            if not block:
                break
            h.update(block)
    finally:
        fp.close()
    return h.hexdigest()


def system_value(args):
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out.strip()


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def load_exact(label, spec, issues):
    path = spec["path"]
    if not os.path.isfile(path):
        issues.append("%s missing" % label)
        return None
    size = os.path.getsize(path)
    digest = sha_file(path)
    if size != spec["size"]:
        issues.append("%s size mismatch" % label)
    if digest != spec["sha"]:
        issues.append("%s SHA mismatch" % label)
    data = open(path, "rb").read()
    return dict(path=path, size=size, sha=digest, data=data)


def parse_sart_matches(data, issues):
    matches = []
    if len(data) < 8:
        issues.append("SArtFile header too short")
        return matches, 0, 0, 0

    version = u16(data, 0)
    count = u16(data, 2)
    data_base = u32(data, 4)
    if version != 2:
        issues.append("SArtFile version mismatch")
    if count != 348:
        issues.append("SArtFile entry count mismatch")
    if SART_TABLE_BASE + count * SART_TABLE_STRIDE > len(data):
        issues.append("SArtFile table outside file")
        return matches, version, count, data_base
    if data_base <= SART_TABLE_BASE + count * SART_TABLE_STRIDE or data_base >= len(data):
        issues.append("SArtFile data base invalid")
        return matches, version, count, data_base

    for index in range(1, count):
        table_off = SART_TABLE_BASE + index * SART_TABLE_STRIDE
        header_off = u32(data, table_off)
        if header_off <= 0 or header_off + 4 > len(data):
            continue
        image_type = u16(data, header_off)
        entry_count = u16(data, header_off + 2)
        for slot in range(min(entry_count, 8)):
            base = header_off + slot * SART_SLOT_STRIDE
            if base + SART_DATA_OFF + 4 > len(data):
                continue
            width = u16(data, base + SART_WIDTH_OFF)
            height = u16(data, base + SART_HEIGHT_OFF)
            length = u32(data, base + SART_LENGTH_OFF)
            rel = u32(data, base + SART_DATA_OFF)
            if length != TARGET_BYTES:
                continue
            absolute = data_base + rel
            if absolute < 0 or absolute + length > len(data):
                continue
            digest = sha_bytes(data[absolute:absolute + length])
            if digest not in TARGET_BY_HASH:
                continue
            matches.append(dict(
                source_id=TARGET_BY_HASH[digest],
                digest=digest,
                lion_id="0x%04x" % (SART_ID_BASE + index),
                index=index,
                image_type=image_type,
                entry_count=entry_count,
                slot=slot,
                width=width,
                height=height,
                provider_rel=rel,
                provider_absolute=absolute,
            ))
    return matches, version, count, data_base


def parse_art_header(data):
    if len(data) < ART_HEADER_SIZE:
        return None
    return dict(
        record_count=u16(data, 0),
        path_len=u16(data, 2),
        component_count=u16(data, 4),
        table_start=u32(data, 8),
        string_pool=u32(data, 12),
        index_start=u32(data, 16),
        payload_start=u32(data, 20),
    )


def parse_art_records(data, header):
    out = []
    rec_size = header["path_len"] + 4
    if rec_size <= 4:
        return out
    for index in range(header["record_count"]):
        off = header["index_start"] + index * rec_size
        if off < 0 or off + rec_size > len(data):
            break
        rel = u32(data, off)
        payload_off = header["payload_start"] + rel
        out.append(dict(
            index=index,
            record_off=off,
            payload_rel=rel,
            payload_off=payload_off,
        ))
    return out


def audit_art_archive(label, data, issues):
    header = parse_art_header(data)
    matches = []
    candidates = 0
    if header is None:
        issues.append("%s header unavailable" % label)
        return header, matches, candidates

    if header["record_count"] <= 0 or header["path_len"] <= 0:
        issues.append("%s header count/path invalid" % label)
        return header, matches, candidates
    if header["payload_start"] <= header["index_start"] or header["payload_start"] >= len(data):
        issues.append("%s payload start invalid" % label)
        return header, matches, candidates

    records = parse_art_records(data, header)
    if len(records) != header["record_count"]:
        issues.append("%s index count mismatch" % label)

    offsets = sorted(set(
        r["payload_off"] for r in records
        if header["payload_start"] <= r["payload_off"] <= len(data)
    ))

    next_by_offset = {}
    for i, start in enumerate(offsets):
        next_by_offset[start] = offsets[i + 1] if i + 1 < len(offsets) else len(data)

    for rec in records:
        start = rec["payload_off"]
        end = next_by_offset.get(start)
        if end is None or start < 0 or end < start or end > len(data):
            continue
        span = data[start:end]
        if len(span) < ART_RECORD_HEADER_SIZE:
            continue

        count0 = u16(span, 0)
        count1 = u16(span, 2)
        cell_count = count0 * count1
        if cell_count <= 0 or cell_count > ART_MAX_CELLS:
            continue

        for cell in range(cell_count):
            off_pos = ART_CELL_OFFSET_BASE + cell * 4
            width_pos = ART_CELL_WIDTH_BASE + cell * 2
            height_pos = ART_CELL_HEIGHT_BASE + cell * 2
            if off_pos + 4 > ART_RECORD_HEADER_SIZE:
                continue
            if width_pos + 2 > ART_RECORD_HEADER_SIZE:
                continue
            if height_pos + 2 > ART_RECORD_HEADER_SIZE:
                continue

            body_off = u32(span, off_pos)
            width = u16(span, width_pos)
            height = u16(span, height_pos)
            body_len = width * height * 4
            if body_len != TARGET_BYTES:
                continue
            if body_off < ART_RECORD_HEADER_SIZE or body_off + body_len > len(span):
                continue

            candidates += 1
            digest = sha_bytes(span[body_off:body_off + body_len])
            if digest not in TARGET_BY_HASH:
                continue
            matches.append(dict(
                source_id=TARGET_BY_HASH[digest],
                digest=digest,
                archive=label,
                record_index=rec["index"],
                record_offset=rec["record_off"],
                payload_offset=start,
                cell=cell,
                body_offset=body_off,
                width=width,
                height=height,
            ))

    return header, matches, candidates


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []

    rc, product = system_value(["/usr/bin/sw_vers", "-productVersion"])
    if rc != 0:
        product = "UNKNOWN"
    rc, build = system_value(["/usr/bin/sw_vers", "-buildVersion"])
    if rc != 0:
        build = "UNKNOWN"

    if product != EXPECTED_PRODUCT:
        issues.append("unexpected product version")
    if build != EXPECTED_BUILD:
        issues.append("unexpected build version")

    loaded = {}
    for label in ("SArtFile", "ArtFile10", "ArtFile20"):
        loaded[label] = load_exact(label, EXPECTED_FILES[label], issues)

    sart_matches = []
    sart_version = 0
    sart_count = 0
    sart_data_base = 0
    if loaded["SArtFile"] is not None:
        sart_matches, sart_version, sart_count, sart_data_base = parse_sart_matches(
            loaded["SArtFile"]["data"], issues)

    art_results = {}
    for label in ("ArtFile10", "ArtFile20"):
        if loaded[label] is None:
            art_results[label] = (None, [], 0)
        else:
            art_results[label] = audit_art_archive(
                label, loaded[label]["data"], issues)

    by_source = dict((source_id, []) for source_id, digest in TARGETS)
    for item in sart_matches:
        by_source[item["source_id"]].append(("SArtFile", item))
    for label in ("ArtFile10", "ArtFile20"):
        for item in art_results[label][1]:
            by_source[item["source_id"]].append((label, item))

    for source_id, expected_lion_id in EXPECTED_SART_MATCHES.items():
        exact = [
            item for archive, item in by_source[source_id]
            if archive == "SArtFile" and item["lion_id"] == expected_lion_id
        ]
        if len(exact) != 1:
            issues.append("expected SArtFile relocation missing or ambiguous for %s" % source_id)

    for source_id in EXPECTED_SART_UNMATCHED:
        exact = [item for archive, item in by_source[source_id] if archive == "SArtFile"]
        if exact:
            issues.append("previously unmatched Snow payload unexpectedly matched SArtFile: %s" % source_id)

    fp = open(output, "w")
    try:
        line(fp, "== PPC Carbon GUI CoreUI Lion legacy payload provenance audit ==")
        line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        line(fp, "product_version=%s" % product)
        line(fp, "build_version=%s" % build)

        line(fp)
        line(fp, "== Resource identities ==")
        for label in ("SArtFile", "ArtFile10", "ArtFile20"):
            obj = loaded[label]
            spec = EXPECTED_FILES[label]
            if obj is None:
                line(fp, "%s_state=MISSING" % label)
                continue
            line(fp, "%s_size=%d" % (label, obj["size"]))
            line(fp, "%s_sha256=%s" % (label, obj["sha"]))
            line(fp, "%s_exact=%s" % (
                label,
                "YES" if obj["size"] == spec["size"] and obj["sha"] == spec["sha"] else "NO"))

        line(fp)
        line(fp, "== Snow source fingerprints ==")
        for source_id, digest in TARGETS:
            line(fp, "source_id=%s provider_bytes=%d sha256=%s" %
                 (source_id, TARGET_BYTES, digest))

        line(fp)
        line(fp, "== Lion SArtFile exact-byte matches ==")
        line(fp, "sartfile_version=%d" % sart_version)
        line(fp, "sartfile_entry_count=%d" % sart_count)
        line(fp, "sartfile_data_region_base=0x%x" % sart_data_base)
        line(fp, "sartfile_match_count=%d" % len(sart_matches))
        for item in sorted(sart_matches, key=lambda x: (x["source_id"], x["lion_id"], x["slot"])):
            line(fp,
                 "sart_match source_id=%s lion_image_id=%s index=%d type=%d count=%d slot=%d width=%d height=%d provider_data_offset=0x%x provider_absolute_offset=0x%x sha256=%s" %
                 (item["source_id"], item["lion_id"], item["index"],
                  item["image_type"], item["entry_count"], item["slot"],
                  item["width"], item["height"], item["provider_rel"],
                  item["provider_absolute"], item["digest"]))

        for label in ("ArtFile10", "ArtFile20"):
            header, matches, candidates = art_results[label]
            line(fp)
            line(fp, "== %s 484-byte old-loader cell inventory ==" % label)
            if header is None:
                line(fp, "header=UNAVAILABLE")
            else:
                line(fp, "record_count=%d" % header["record_count"])
                line(fp, "path_len=%d" % header["path_len"])
                line(fp, "component_count=%d" % header["component_count"])
                line(fp, "index_start=0x%x" % header["index_start"])
                line(fp, "payload_start=0x%x" % header["payload_start"])
                line(fp, "candidate_cell_count=%d" % candidates)
                line(fp, "target_match_count=%d" % len(matches))
                for item in sorted(matches, key=lambda x: (x["source_id"], x["record_index"], x["cell"])):
                    line(fp,
                         "art_match source_id=%s archive=%s record_index=%d record_offset=0x%x payload_offset=0x%x cell=%d body_offset=0x%x width=%d height=%d sha256=%s" %
                         (item["source_id"], item["archive"], item["record_index"],
                          item["record_offset"], item["payload_offset"], item["cell"],
                          item["body_offset"], item["width"], item["height"], item["digest"]))

        line(fp)
        line(fp, "== Per-source provenance summary ==")
        for source_id, digest in TARGETS:
            entries = by_source[source_id]
            line(fp, "source_id=%s total_exact_byte_matches=%d" % (source_id, len(entries)))
            if not entries:
                line(fp, "provenance source_id=%s state=NO_EXACT_MATCH_IN_LION_SARTFILE_ARTFILE10_ARTFILE20" % source_id)
                continue
            for archive, item in entries:
                if archive == "SArtFile":
                    line(fp, "provenance source_id=%s archive=SArtFile lion_image_id=%s slot=%d width=%d height=%d" %
                         (source_id, item["lion_id"], item["slot"], item["width"], item["height"]))
                else:
                    line(fp, "provenance source_id=%s archive=%s record_index=%d cell=%d width=%d height=%d" %
                         (source_id, archive, item["record_index"], item["cell"],
                          item["width"], item["height"]))

        line(fp)
        line(fp, "== Audit validation ==")
        if issues:
            for issue in issues:
                line(fp, "validation_issue=%s" % issue)
            line(fp, "RESULT: FAIL")
        else:
            line(fp, "lion_legacy_payload_provenance_audit_exact=YES")
            line(fp, "RESULT: PASS")

        line(fp)
        line(fp, "== Audit integrity ==")
        line(fp, "No PowerPC subject was launched.")
        line(fp, "No process was attached.")
        line(fp, "No compatibility artifact was built or loaded.")
        line(fp, "All CoreUI resource archives were opened read-only.")
        line(fp, "Only SHA-256 fingerprints of Snow payloads are embedded; no Snow image bytes are copied to Lion.")
        line(fp, "No CoreUI resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
    finally:
        fp.close()

    print("Created: %s" % output)
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
