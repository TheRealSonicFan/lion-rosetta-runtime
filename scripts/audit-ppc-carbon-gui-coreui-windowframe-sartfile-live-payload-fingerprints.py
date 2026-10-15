#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-v1"

SARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        sart_size=811436,
        sart_sha="62eb745beaafa0a24111c0ac3b3452cebfda4aeec5e56e51b054ae2d62f778b2",
        count=237,
    ),
    "10.7.5": dict(
        build="11G63",
        sart_size=9370228,
        sart_sha="29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b",
        count=348,
    ),
}

SHARED_IMAGE_ID_BASE = 0x4e20
OFFSET_TABLE_BASE = 0x08
OFFSET_TABLE_STRIDE = 4
SLOT_STRIDE = 0x0c
WIDTH_OFFSET = 0x0c
HEIGHT_OFFSET = 0x0e
LENGTH_OFFSET = 0x10
DATA_OFFSET = 0x14

# Exact five frame IDs recovered by the healthy Snow live raw trace, in order.
LIVE_ACTIVE_IDS = [
    0x4e8e,
    0x4e90,
    0x4e8d,
    0x4e8f,
    0x4e91,
]

LION_EXPECTED_TYPE_COUNT = {
    0x4e8e: (1, 2),
    0x4e90: (3, 3),
    0x4e8d: (1, 2),
    0x4e8f: (3, 3),
    0x4e91: (3, 3),
}


def u16le(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32le(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    fp = open(path, "rb")
    try:
        while True:
            chunk = fp.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    finally:
        fp.close()
    return h.hexdigest()


def system_value(args):
    import subprocess
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out.strip()


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def read_record(data, count, image_id, data_region_base):
    index = image_id - SHARED_IMAGE_ID_BASE
    table_off = OFFSET_TABLE_BASE + index * OFFSET_TABLE_STRIDE
    if index <= 0 or index >= count:
        return None
    if table_off + 4 > len(data):
        return None
    header_off = u32le(data, table_off)
    if header_off <= 0 or header_off + 0x18 > len(data):
        return None

    image_type = u16le(data, header_off)
    entry_count = u16le(data, header_off + 2)
    slots = []
    slot_limit = min(entry_count, 8)
    for slot in range(slot_limit):
        base = header_off + slot * SLOT_STRIDE
        if base + DATA_OFFSET + 4 > len(data):
            break
        width = u16le(data, base + WIDTH_OFFSET)
        height = u16le(data, base + HEIGHT_OFFSET)
        length = u32le(data, base + LENGTH_OFFSET)
        rel = u32le(data, base + DATA_OFFSET)
        absolute = data_region_base + rel
        valid = (length > 0 and absolute >= 0 and absolute + length <= len(data))
        digest = "INVALID"
        if valid:
            digest = sha256_bytes(data[absolute:absolute + length])
        slots.append(dict(
            slot=slot,
            width=width,
            height=height,
            length=length,
            rel=rel,
            absolute=absolute,
            valid=valid,
            sha=digest,
        ))

    return dict(
        image_id=image_id,
        index=index,
        table_off=table_off,
        header_off=header_off,
        image_type=image_type,
        entry_count=entry_count,
        slots=slots,
    )


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    out_path = sys.argv[1]
    issues = []

    rc, product = system_value(["/usr/bin/sw_vers", "-productVersion"])
    if rc != 0:
        product = "UNKNOWN"
    rc, build = system_value(["/usr/bin/sw_vers", "-buildVersion"])
    if rc != 0:
        build = "UNKNOWN"

    expected = EXPECTED.get(product)
    if expected is None:
        expected = EXPECTED["10.7.5"]
        issues.append("unsupported product version: %s" % product)
    elif build != expected["build"]:
        issues.append("unexpected build version")

    if not os.path.isfile(SARTFILE):
        print("error: missing SArtFile.bin", file=sys.stderr)
        return 66

    size = os.path.getsize(SARTFILE)
    digest = sha256_file(SARTFILE)
    data = open(SARTFILE, "rb").read()

    if size != expected["sart_size"]:
        issues.append("SArtFile size mismatch")
    if digest != expected["sart_sha"]:
        issues.append("SArtFile SHA mismatch")
    if len(data) < 8:
        issues.append("SArtFile header too short")
        version = 0
        count = 0
        data_region_base = 0
    else:
        version = u16le(data, 0)
        count = u16le(data, 2)
        data_region_base = u32le(data, 4)

    if version != 2:
        issues.append("unexpected SArtFile version")
    if count != expected["count"]:
        issues.append("unexpected SArtFile entry count")
    if OFFSET_TABLE_BASE + count * OFFSET_TABLE_STRIDE > len(data):
        issues.append("offset table outside SArtFile")
    if data_region_base <= OFFSET_TABLE_BASE + count * OFFSET_TABLE_STRIDE:
        issues.append("data region base overlaps offset table")
    if data_region_base >= len(data):
        issues.append("data region base outside SArtFile")

    active = []
    for image_id in LIVE_ACTIVE_IDS:
        rec = read_record(data, count, image_id, data_region_base)
        if rec is None:
            issues.append("live-active record missing: 0x%04x" % image_id)
            continue
        active.append(rec)

        if product == "10.6.8":
            if (rec["image_type"], rec["entry_count"]) != (2, 1):
                issues.append("Snow live-active type/count mismatch: 0x%04x" % image_id)
            if not rec["slots"]:
                issues.append("Snow live-active slot missing: 0x%04x" % image_id)
            else:
                s = rec["slots"][0]
                if (s["width"], s["height"], s["length"]) != (11, 11, 484):
                    issues.append("Snow live-active payload geometry mismatch: 0x%04x" % image_id)
                if not s["valid"]:
                    issues.append("Snow live-active provider range invalid: 0x%04x" % image_id)
        elif product == "10.7.5":
            expected_tc = LION_EXPECTED_TYPE_COUNT[image_id]
            if (rec["image_type"], rec["entry_count"]) != expected_tc:
                issues.append("Lion live-active type/count mismatch: 0x%04x" % image_id)

    candidates = []
    if product == "10.7.5":
        for index in range(1, count):
            image_id = SHARED_IMAGE_ID_BASE + index
            rec = read_record(data, count, image_id, data_region_base)
            if rec is None:
                continue
            for s in rec["slots"]:
                if (s["width"], s["height"], s["length"]) == (11, 11, 484) and s["valid"]:
                    candidates.append((rec, s))

    fp = open(out_path, "w")
    try:
        line(fp, "== PPC Carbon GUI CoreUI live-active SArtFile payload fingerprint audit ==")
        line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        line(fp, "product_version=%s" % product)
        line(fp, "build_version=%s" % build)
        line(fp, "sartfile_sha256=%s" % digest)
        line(fp, "expected_sartfile_sha256=%s" % expected["sart_sha"])
        line(fp, "sartfile_exact=%s" % ("YES" if digest == expected["sart_sha"] and size == expected["sart_size"] else "NO"))
        line(fp, "sartfile_size=%d" % size)
        line(fp, "sartfile_version=%d" % version)
        line(fp, "sartfile_entry_count=%d" % count)
        line(fp, "sartfile_data_region_base=0x%x" % data_region_base)
        line(fp, "provider_absolute_offset_formula=data_region_base+provider_data_offset")
        line(fp, "offset_table_base=0x%02x" % OFFSET_TABLE_BASE)
        line(fp, "live_active_id_count=%d" % len(LIVE_ACTIVE_IDS))

        line(fp)
        line(fp, "== Exact five Snow-live-active frame IDs ==")
        for rec in active:
            line(fp,
                 "record image_id=0x%04x index=%d type=%d count=%d header_offset=0x%x" %
                 (rec["image_id"], rec["index"], rec["image_type"],
                  rec["entry_count"], rec["header_off"]))
            for s in rec["slots"]:
                line(fp,
                     "slot image_id=0x%04x slot=%d width=%d height=%d provider_length=%d provider_data_offset=0x%x provider_absolute_offset=0x%x provider_range_valid=%s provider_sha256=%s" %
                     (rec["image_id"], s["slot"], s["width"], s["height"],
                      s["length"], s["rel"], s["absolute"],
                      "YES" if s["valid"] else "NO", s["sha"]))

        if product == "10.7.5":
            line(fp)
            line(fp, "== Lion SArtFile exact 11x11x4 provider candidates ==")
            line(fp, "candidate_count=%d" % len(candidates))
            for rec, s in candidates:
                line(fp,
                     "candidate image_id=0x%04x index=%d type=%d count=%d slot=%d provider_data_offset=0x%x provider_absolute_offset=0x%x provider_sha256=%s" %
                     (rec["image_id"], rec["index"], rec["image_type"],
                      rec["entry_count"], s["slot"], s["rel"], s["absolute"], s["sha"]))

            line(fp)
            line(fp, "== Deterministic live branch partition ==")
            line(fp, "lion_live_raw_slot1_ids=0x4e8e,0x4e8d")
            line(fp, "lion_live_imageio_ids_by_active_set_type_partition=0x4e90,0x4e8f,0x4e91")
            line(fp, "partition_basis=Snow-active-five minus exact-two Lion raw IDs; remaining three are type-3/count-3 and Lion ImageIO count is exactly three")

        line(fp)
        line(fp, "== Audit validation ==")
        if issues:
            for issue in issues:
                line(fp, "validation_issue=%s" % issue)
            line(fp, "RESULT: FAIL")
        else:
            line(fp, "live_active_payload_fingerprint_audit_exact=YES")
            line(fp, "RESULT: PASS")

        line(fp)
        line(fp, "== Audit integrity ==")
        line(fp, "No PowerPC subject was launched.")
        line(fp, "No process was attached.")
        line(fp, "No compatibility artifact was built or loaded.")
        line(fp, "No CoreUI resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
        line(fp, "SArtFile.bin was opened read-only.")
        line(fp, "No Snow image bytes are copied to Lion by this analyzer.")
    finally:
        fp.close()

    print("Created: %s" % out_path)
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
