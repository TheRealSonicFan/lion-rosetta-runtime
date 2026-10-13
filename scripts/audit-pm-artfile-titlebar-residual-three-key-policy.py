#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import subprocess
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "titlebar-residual-three-key-policy-v1"
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

POLICY = [
    (
        "active-clear",
        (0xa6, 0x01, 0x13, 0x16, 0x7a, 0x00, 0x00, 0x00),
        (0x99, 0x01, 0x14, 0x17, 0x72, 0x00, 0x00, 0x00),
        ("titlebarcontrols", "active", "close", "colorsryg", "regularwin"),
    ),
    (
        "active-minus",
        (0xa6, 0x01, 0x16, 0x56, 0x7a, 0x00, 0x00, 0x00),
        (0x99, 0x01, 0x17, 0x55, 0x72, 0x00, 0x00, 0x00),
        ("titlebarcontrols", "active", "colorsryg", "minimize", "regularwin"),
    ),
    (
        "active-zoom",
        (0xa6, 0x01, 0x16, 0x7a, 0xb6, 0x00, 0x00, 0x00),
        (0x99, 0x01, 0x17, 0x72, 0xa9, 0x00, 0x00, 0x00),
        ("titlebarcontrols", "active", "colorsryg", "regularwin", "zoom"),
    ),
]

ORIGINAL_POLICY_SOURCES = [
    (0xa6, 0x13, 0x16, 0x1f, 0x7a, 0x00, 0x00, 0x00),
    (0xa6, 0x16, 0x1f, 0x56, 0x7a, 0x00, 0x00, 0x00),
    (0xa6, 0x16, 0x1f, 0x7a, 0xb6, 0x00, 0x00, 0x00),
]

ORIGINAL_POLICY_TARGETS = [
    (0x99, 0x14, 0x17, 0x22, 0x72, 0x00, 0x00, 0x00),
    (0x99, 0x17, 0x22, 0x55, 0x72, 0x00, 0x00, 0x00),
    (0x99, 0x17, 0x22, 0x72, 0xa9, 0x00, 0x00, 0x00),
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


def bytes_from_ids(values):
    return "".join(chr(value) for value in values)


def hexbytes(data):
    return "".join("%02x" % bval(ch) for ch in data)


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
    by_id = {}
    for ident in range(1, header["component_count"] + 1):
        entry = header["table_start"] + (ident - 1) * 8
        if entry + 8 > header["string_pool"] or entry + 8 > len(data):
            continue
        rel = u32le(data, entry)
        text = cstring(data, header["string_pool"] + rel)
        if text is not None:
            by_id[ident] = text
    return by_id


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
    for ch in key:
        ident = bval(ch)
        if ident == 0:
            break
        names.append(by_id.get(ident, "<invalid-0x%02x>" % ident))
    return tuple(names)


def lion_guard(product, build, art_size, art_sha, header):
    expected = EXPECTED["10.7.5"]
    if product != "10.7.5" or build != expected["build"]:
        return False
    if art_size != expected["size"] or art_sha != expected["sha256"]:
        return False
    if header is None:
        return False
    for key in [
        "record_count", "path_len", "component_count", "table_start",
        "string_pool", "index_start", "payload_start"
    ]:
        if header.get(key) != expected[key]:
            return False
    record_size = header["path_len"] + 4
    index_end = header["index_start"] + header["record_count"] * record_size
    return header["payload_start"] - index_end == expected["index_padding"]


def translate_key(key, enabled):
    if not enabled:
        return key, "IDENTITY_GUARD_DISABLED"
    for label, snow_ids, lion_ids, semantics in POLICY:
        source = bytes_from_ids(snow_ids)
        if key == source:
            return bytes_from_ids(lion_ids), "TRANSLATED_" + label.upper()
    return key, "IDENTITY_NON_TARGET"


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./pm-art-titlebar-residual-three-key-policy.txt"
    issues = []

    _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
    product = product_out.strip()
    _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
    build = build_out.strip()

    expected = EXPECTED.get(product)
    if expected is None:
        issues.append("unsupported product version: %s" % product)

    if not os.path.isfile(ARTFILE):
        data = ""
        art_size = -1
        art_sha = "MISSING"
        issues.append("ArtFile.bin missing")
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
                issues.append("header %s mismatch" % key)

    record_size = header["path_len"] + 4
    index_end = header["index_start"] + header["record_count"] * record_size
    index_padding = header["payload_start"] - index_end
    if expected is not None and index_padding != expected["index_padding"]:
        issues.append("path index padding mismatch")

    records = parse_index(data, header)
    if len(records) != header["record_count"]:
        issues.append("path index record count mismatch")

    by_id = parse_dictionary(data, header)
    guard_enabled = lion_guard(product, build, art_size, art_sha, header)

    if len(POLICY) != 3:
        issues.append("policy entry count is not exactly three")
    sources = [bytes_from_ids(item[1]) for item in POLICY]
    targets = [bytes_from_ids(item[2]) for item in POLICY]
    if len(set(sources)) != 3:
        issues.append("policy source keys are not unique")
    if len(set(targets)) != 3:
        issues.append("policy target keys are not unique")
    if set(sources).intersection(set(targets)):
        issues.append("policy source/target key sets overlap")

    original_sources = set(bytes_from_ids(values) for values in ORIGINAL_POLICY_SOURCES)
    original_targets = set(bytes_from_ids(values) for values in ORIGINAL_POLICY_TARGETS)
    if set(sources).intersection(original_sources):
        issues.append("residual policy source overlaps original exact-three source set")
    if set(targets).intersection(original_targets):
        issues.append("residual policy target overlaps original exact-three target set")

    exact_guard = lion_guard(
        "10.7.5", EXPECTED["10.7.5"]["build"], EXPECTED["10.7.5"]["size"],
        EXPECTED["10.7.5"]["sha256"], EXPECTED["10.7.5"]
    )
    guard_negative_tests = [
        lion_guard("10.6.8", "11G63", EXPECTED["10.7.5"]["size"], EXPECTED["10.7.5"]["sha256"], EXPECTED["10.7.5"]),
        lion_guard("10.7.5", "BAD", EXPECTED["10.7.5"]["size"], EXPECTED["10.7.5"]["sha256"], EXPECTED["10.7.5"]),
        lion_guard("10.7.5", "11G63", EXPECTED["10.7.5"]["size"] + 1, EXPECTED["10.7.5"]["sha256"], EXPECTED["10.7.5"]),
        lion_guard("10.7.5", "11G63", EXPECTED["10.7.5"]["size"], "0" * 64, EXPECTED["10.7.5"]),
    ]
    guard_selftest_pass = exact_guard and not any(guard_negative_tests)
    if not guard_selftest_pass:
        issues.append("release/resource guard self-test failed")

    policy_rows = []
    for label, snow_ids, lion_ids, semantics in POLICY:
        source = bytes_from_ids(snow_ids)
        target = bytes_from_ids(lion_ids)
        source_hits = [r for r in records if r["key"] == source]
        target_hits = [r for r in records if r["key"] == target]
        target_payload_valid = bool(target_hits) and all(
            r["payload_off"] >= 0 and r["payload_off"] + 0x68 <= len(data)
            for r in target_hits
        )

        forced_out, forced_action = translate_key(source, True)
        if forced_out != target or not forced_action.startswith("TRANSLATED_"):
            issues.append("%s exact mapping self-test failed" % label)

        target_second, target_action = translate_key(target, True)
        if target_second != target or target_action != "IDENTITY_NON_TARGET":
            issues.append("%s target idempotence self-test failed" % label)

        if product == "10.6.8":
            if len(source_hits) != 1:
                issues.append("%s Snow source-key hit count != 1" % label)
            guarded_out, guarded_action = translate_key(source, guard_enabled)
            if guarded_out != source or guarded_action != "IDENTITY_GUARD_DISABLED":
                issues.append("%s Snow guard-disable behavior failed" % label)
        elif product == "10.7.5":
            if not guard_enabled:
                issues.append("Lion release/resource guard did not enable")
            if len(source_hits) != 0:
                issues.append("%s untranslated Snow key unexpectedly exists in Lion index" % label)
            if len(target_hits) != 1:
                issues.append("%s Lion target-key hit count != 1" % label)
            if not target_payload_valid:
                issues.append("%s Lion target payload is invalid" % label)
            if decode_key(target, by_id) != semantics:
                issues.append("%s Lion target semantic decode mismatch" % label)
            guarded_out, guarded_action = translate_key(source, guard_enabled)
            if guarded_out != target:
                issues.append("%s Lion guarded mapping failed" % label)

        policy_rows.append({
            "label": label,
            "semantics": semantics,
            "source": source,
            "target": target,
            "source_hits": source_hits,
            "target_hits": target_hits,
            "target_payload_valid": target_payload_valid,
            "decoded_target": decode_key(target, by_id),
        })

    near_miss_cases = 0
    near_miss_failures = 0
    for source in sources:
        source_ids = [bval(ch) for ch in source]
        for pos in range(8):
            for value in range(256):
                if value == source_ids[pos]:
                    continue
                mutated = list(source_ids)
                mutated[pos] = value
                candidate = bytes_from_ids(mutated)
                out, action = translate_key(candidate, True)
                near_miss_cases += 1
                if out != candidate or action != "IDENTITY_NON_TARGET":
                    near_miss_failures += 1
    if near_miss_failures:
        issues.append("single-byte near-miss identity proof failed")

    changed_index_records = []
    for record in records:
        out, action = translate_key(record["key"], guard_enabled)
        if out != record["key"]:
            changed_index_records.append((record, out, action))

    if product in EXPECTED and changed_index_records:
        issues.append("local ArtFile index contains a path changed by current guarded policy")

    with open(report, "w") as fp:
        write_line(fp, "== CoreUI titlebar residual exact-three-key policy proof ==")
        write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
        write_line(fp, "product_version=%s" % product)
        write_line(fp, "build_version=%s" % build)
        write_line(fp, "artfile_size=%d" % art_size)
        write_line(fp, "artfile_sha256=%s" % art_sha)

        write_line(fp)
        write_line(fp, "== Guard contract ==")
        write_line(fp, "activation_product=10.7.5")
        write_line(fp, "activation_build=11G63")
        write_line(fp, "activation_artfile_sha256=%s" % EXPECTED["10.7.5"]["sha256"])
        write_line(fp, "predicate_mode=exact_full_8_byte_equality")
        write_line(fp, "fallback_behavior=identity")
        write_line(fp, "guard_enabled=%s" % ("YES" if guard_enabled else "NO"))
        write_line(fp, "guard_selftest=%s" % ("PASS" if guard_selftest_pass else "FAIL"))

        write_line(fp)
        write_line(fp, "== Policy table ==")
        write_line(fp, "policy_entry_count=%d" % len(POLICY))
        for row in policy_rows:
            write_line(fp, "path=%s" % row["label"])
            write_line(fp, "semantic_path=%s" % ".".join(row["semantics"]))
            write_line(fp, "source_snow_key=%s" % hexbytes(row["source"]))
            write_line(fp, "target_lion_key=%s" % hexbytes(row["target"]))
            write_line(fp, "local_source_index_hits=%d" % len(row["source_hits"]))
            write_line(fp, "local_target_index_hits=%d" % len(row["target_hits"]))
            write_line(fp, "local_target_decoded=%s" % ".".join(row["decoded_target"]))
            write_line(fp, "local_target_payload_0x68_valid=%s" % ("YES" if row["target_payload_valid"] else "NO"))
            if row["target_hits"]:
                hit = row["target_hits"][0]
                write_line(fp, "local_target_payload_off=0x%x" % hit["payload_off"])
            write_line(fp)

        write_line(fp, "== Non-target identity proof ==")
        write_line(fp, "single_byte_near_miss_cases=%d" % near_miss_cases)
        write_line(fp, "single_byte_near_miss_failures=%d" % near_miss_failures)
        write_line(fp, "local_index_records_checked=%d" % len(records))
        write_line(fp, "local_index_records_changed=%d" % len(changed_index_records))
        write_line(fp, "target_outputs_are_policy_sources=NO")
        write_line(fp, "policy_idempotence=PASS" if not set(sources).intersection(set(targets)) else "policy_idempotence=FAIL")
        write_line(fp, "original_policy_source_overlap=%d" % len(set(sources).intersection(original_sources)))
        write_line(fp, "original_policy_target_overlap=%d" % len(set(targets).intersection(original_targets)))

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
        write_line(fp, "The translation policy was exercised only as an in-process Python byte function.")
        write_line(fp, "No PowerPC subject was launched.")
        write_line(fp, "No process was attached.")
        write_line(fp, "No interposer was built or installed.")
        write_line(fp, "The already-live original exact-three interposer policy was not changed.")
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
