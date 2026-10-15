#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import subprocess
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-v1"

SARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"
EXPECTED_PRODUCT = "10.7.5"
EXPECTED_BUILD = "11G63"
EXPECTED_SIZE = 9370228
EXPECTED_SHA256 = "29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b"
EXPECTED_VERSION = 2
EXPECTED_COUNT = 348
EXPECTED_DATA_BASE = 0x3ff0
IMAGE_ID_BASE = 0x4e20
TABLE_BASE = 0x08

TARGETS = [
    dict(lion_id=0x4e75, legacy_id=0x4e8d, header=0x1488, slot0_rel=0x1ebffc,
         exact_anchor="9577c7876e34e40a778511795c7a28702af3613dca28b5edeac5f6972ff9912e"),
    dict(lion_id=0x4e76, legacy_id=0x4e8e, header=0x14ac, slot0_rel=0x1ec970,
         exact_anchor="44897e71f9f949fa7b276adc71a2d58c02ebaab80721ac0035d113fd9f37288f"),
    dict(lion_id=0x4e77, legacy_id=0x4e8f, header=0x14d0, slot0_rel=0x1ed2e4,
         exact_anchor=None),
    dict(lion_id=0x4e78, legacy_id=0x4e90, header=0x14f4, slot0_rel=0x1edc58,
         exact_anchor="ba825c44fbcb9a52febacfdd60c29383b3a9fb83d3740789f434e28b1cbf1cd7"),
    dict(lion_id=0x4e79, legacy_id=0x4e91, header=0x1518, slot0_rel=0x1ee5cc,
         exact_anchor=None),
]


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out.strip()


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


def byte_value(ch):
    return ch if isinstance(ch, int) else ord(ch)


def u16(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def pixel_model(body, alpha_index):
    violations = 0
    zero_alpha_with_color = 0
    nonzero_alpha = 0
    opaque_alpha = 0
    alpha_sum = 0
    xs = []
    ys = []
    pixels = len(body) // 4
    width = 11
    for index in range(pixels):
        px = [byte_value(body[index * 4 + j]) for j in range(4)]
        alpha = px[alpha_index]
        colors = [px[j] for j in range(4) if j != alpha_index]
        alpha_sum += alpha
        if alpha != 0:
            nonzero_alpha += 1
            xs.append(index % width)
            ys.append(index // width)
        if alpha == 255:
            opaque_alpha += 1
        if alpha == 0 and any(value != 0 for value in colors):
            zero_alpha_with_color += 1
        if any(value > alpha for value in colors):
            violations += 1
    if xs:
        bbox = "%d,%d,%d,%d" % (min(xs), min(ys), max(xs), max(ys))
    else:
        bbox = "EMPTY"
    return dict(
        premul_violations=violations,
        zero_alpha_with_color=zero_alpha_with_color,
        nonzero_alpha=nonzero_alpha,
        opaque_alpha=opaque_alpha,
        alpha_sum=alpha_sum,
        nonzero_bbox=bbox,
    )


def score(model):
    return model["premul_violations"] + model["zero_alpha_with_color"]


def preferred(model0, model3):
    s0 = score(model0)
    s3 = score(model3)
    if s0 < s3:
        return "BYTE0"
    if s3 < s0:
        return "BYTE3"
    return "AMBIGUOUS"


def alpha_mask(body, alpha_index):
    rows = []
    for y in range(11):
        row = []
        for x in range(11):
            alpha = byte_value(body[(y * 11 + x) * 4 + alpha_index])
            if alpha == 0:
                row.append(".")
            elif alpha < 64:
                row.append("1")
            elif alpha < 128:
                row.append("2")
            elif alpha < 192:
                row.append("3")
            elif alpha < 255:
                row.append("4")
            else:
                row.append("#")
        rows.append("".join(row))
    return "/".join(rows)


def line(fp, s=""):
    fp.write(s)
    fp.write("\n")


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []

    rc, product = run(["/usr/bin/sw_vers", "-productVersion"])
    if rc != 0:
        product = "UNKNOWN"
    rc, build = run(["/usr/bin/sw_vers", "-buildVersion"])
    if rc != 0:
        build = "UNKNOWN"

    if product != EXPECTED_PRODUCT:
        issues.append("unexpected product version")
    if build != EXPECTED_BUILD:
        issues.append("unexpected build version")
    if not os.path.isfile(SARTFILE):
        print("error: missing SArtFile.bin", file=sys.stderr)
        return 66

    size = os.path.getsize(SARTFILE)
    digest = sha256_file(SARTFILE)
    data = open(SARTFILE, "rb").read()

    if size != EXPECTED_SIZE:
        issues.append("SArtFile size mismatch")
    if digest != EXPECTED_SHA256:
        issues.append("SArtFile SHA mismatch")
    if len(data) < 8:
        issues.append("SArtFile header too short")
        version = count = data_base = 0
    else:
        version = u16(data, 0)
        count = u16(data, 2)
        data_base = u32(data, 4)

    if version != EXPECTED_VERSION:
        issues.append("SArtFile version mismatch")
    if count != EXPECTED_COUNT:
        issues.append("SArtFile count mismatch")
    if data_base != EXPECTED_DATA_BASE:
        issues.append("SArtFile data-base mismatch")

    rows = []
    for target in TARGETS:
        idx = target["lion_id"] - IMAGE_ID_BASE
        table_off = TABLE_BASE + idx * 4
        if table_off + 4 > len(data):
            issues.append("table lookup out of range: 0x%04x" % target["lion_id"])
            continue
        header = u32(data, table_off)
        if header != target["header"]:
            issues.append("header mismatch: 0x%04x" % target["lion_id"])
            continue
        if header + 0x18 > len(data):
            issues.append("header out of range: 0x%04x" % target["lion_id"])
            continue
        image_type = u16(data, header)
        entry_count = u16(data, header + 2)
        width = u16(data, header + 0x0c)
        height = u16(data, header + 0x0e)
        length = u32(data, header + 0x10)
        rel = u32(data, header + 0x14)
        absolute = data_base + rel
        valid = absolute >= 0 and absolute + length <= len(data)
        if (image_type, entry_count) != (1, 2):
            issues.append("type/count mismatch: 0x%04x" % target["lion_id"])
        if (width, height, length) != (11, 11, 484):
            issues.append("slot0 geometry mismatch: 0x%04x" % target["lion_id"])
        if rel != target["slot0_rel"]:
            issues.append("slot0 provider offset mismatch: 0x%04x" % target["lion_id"])
        if not valid:
            issues.append("slot0 provider range invalid: 0x%04x" % target["lion_id"])
            continue
        body = data[absolute:absolute + length]
        body_sha = hashlib.sha256(body).hexdigest()
        if target["exact_anchor"] is not None and body_sha != target["exact_anchor"]:
            issues.append("exact-byte anchor mismatch: 0x%04x" % target["lion_id"])
        model0 = pixel_model(body, 0)
        model3 = pixel_model(body, 3)
        pref = preferred(model0, model3)
        rows.append(dict(
            target=target, sha=body_sha, model0=model0, model3=model3,
            preferred=pref, mask0=alpha_mask(body, 0), mask3=alpha_mask(body, 3)
        ))

    if len(rows) != 5:
        issues.append("target decode count mismatch")

    fp = open(output, "w")
    try:
        line(fp, "== PPC Carbon GUI CoreUI mapped slot0 pixel-format audit ==")
        line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        line(fp, "product_version=%s" % product)
        line(fp, "build_version=%s" % build)
        line(fp, "sartfile_size=%d" % size)
        line(fp, "sartfile_sha256=%s" % digest)
        line(fp, "sartfile_exact=%s" % ("YES" if size == EXPECTED_SIZE and digest == EXPECTED_SHA256 else "NO"))
        line(fp, "sartfile_version=%d" % version)
        line(fp, "sartfile_entry_count=%d" % count)
        line(fp, "sartfile_data_region_base=0x%x" % data_base)

        line(fp)
        line(fp, "== Five mapped Lion slot0 payloads ==")
        for row in rows:
            t = row["target"]
            line(fp, "mapping legacy_id=0x%04x lion_id=0x%04x slot0_sha256=%s exact_snow_anchor=%s" %
                 (t["legacy_id"], t["lion_id"], row["sha"],
                  "YES" if t["exact_anchor"] is not None else "NO"))
            for label, model in (("byte0", row["model0"]), ("byte3", row["model3"])):
                line(fp, "alpha_%s legacy_id=0x%04x lion_id=0x%04x premul_violations=%d zero_with_color=%d nonzero=%d opaque=%d alpha_sum=%d nonzero_bbox=%s" %
                     (label, t["legacy_id"], t["lion_id"],
                      model["premul_violations"], model["zero_alpha_with_color"],
                      model["nonzero_alpha"], model["opaque_alpha"],
                      model["alpha_sum"], model["nonzero_bbox"]))
            line(fp, "preferred_alpha_byte legacy_id=0x%04x lion_id=0x%04x value=%s score0=%d score3=%d" %
                 (t["legacy_id"], t["lion_id"], row["preferred"],
                  score(row["model0"]), score(row["model3"])))
            line(fp, "alpha_mask_byte0 legacy_id=0x%04x value=%s" %
                 (t["legacy_id"], row["mask0"]))
            line(fp, "alpha_mask_byte3 legacy_id=0x%04x value=%s" %
                 (t["legacy_id"], row["mask3"]))

        line(fp)
        line(fp, "== Decision inputs ==")
        byte0_ids = [r["target"]["legacy_id"] for r in rows if r["preferred"] == "BYTE0"]
        byte3_ids = [r["target"]["legacy_id"] for r in rows if r["preferred"] == "BYTE3"]
        ambiguous_ids = [r["target"]["legacy_id"] for r in rows if r["preferred"] == "AMBIGUOUS"]
        line(fp, "preferred_byte0_ids=%s" % ",".join("0x%04x" % x for x in byte0_ids))
        line(fp, "preferred_byte3_ids=%s" % ",".join("0x%04x" % x for x in byte3_ids))
        line(fp, "ambiguous_ids=%s" % (",".join("0x%04x" % x for x in ambiguous_ids) or "NONE"))
        line(fp, "current_slot0_adapter_bitmapinfo=0x00000002_for_all_five")
        line(fp, "visual_observation_from_prior_live_run=titlebar_background_restored_but_top_corners_missing")
        line(fp, "notification_observation_from_prior_live_run=exact_prior_registration_7_payload_276_absent;_prior_8_to_21_sequence_shifted_to_7_to_20")

        line(fp)
        line(fp, "== Validation ==")
        if issues:
            for issue in issues:
                line(fp, "validation_issue=%s" % issue)
            line(fp, "RESULT: FAIL")
        else:
            line(fp, "mapped_slot0_pixel_format_audit_exact=YES")
            line(fp, "RESULT: PASS")

        line(fp)
        line(fp, "== Integrity ==")
        line(fp, "No PowerPC subject was launched.")
        line(fp, "No process was attached.")
        line(fp, "SArtFile.bin was opened read-only.")
        line(fp, "No compatibility dylib was built or loaded.")
        line(fp, "No CoreUI resource, Rosetta cache, WindowServer, CGS, or XNU state was modified.")
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
