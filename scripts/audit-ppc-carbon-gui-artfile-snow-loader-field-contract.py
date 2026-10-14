#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import shutil
import struct
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-artfile-snow-loader-field-contract-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_CACHE_SHA256 = "2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA256 = "66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_SNOW_COREUI_SHA256 = "84e57e7ba218986b8a272eaff44f2235c212f6d2091bc078ef1f106bfef48f23"
EXPECTED_SNOW_COREUI_PPC_SHA256 = "5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        art_size=5946480,
        art_sha256="1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        record_count=3324,
        path_len=8,
        component_count=182,
        table_start=0x18,
        string_pool=0x5c8,
        index_start=0xc4a,
        payload_start=0xa81c,
    ),
    "10.7.5": dict(
        build="11G63",
        art_size=4765184,
        art_sha256="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        record_count=2674,
        path_len=8,
        component_count=169,
        table_start=0x18,
        string_pool=0x560,
        index_start=0xb9d,
        payload_start=0x88f8,
    ),
}

LOAD_FROM_ARTFILE = "__ZN10CUIElement15LoadFromArtFileEPKh"
EXPECTED_LOAD_FROM_ARTFILE = 0x29408

# Exact Snow-PPC instructions that establish the serialized record contract.
EXPECTED_INSTRUCTIONS = {
    0x29530: ("li", "r5,0x68"),
    0x29534: ("addi", "r3,r1,0x118"),
    0x29564: ("_memcpy", None),

    0x29578: ("lhz", "r0,0x118(r1)"),
    0x29574: ("lhz", "r2,0x11a(r1)"),
    0x2956c: ("lhz", "r9,0x11c(r1)"),
    0x29568: ("lhz", "r11,0x11e(r1)"),
    0x2957c: ("lhz", "r10,0x120(r1)"),
    0x295b4: ("lhz", "r9,0x122(r1)"),
    0x295d8: ("lhz", "r10,0x124(r1)"),
    0x29588: ("lhz", "r5,0x126(r1)"),
    0x29584: ("lhz", "r3,0x128(r1)"),
    0x29580: ("lhz", "r4,0x12a(r1)"),
    0x29618: ("lhz", "r27,0x12c(r1)"),
    0x29614: ("lhz", "r28,0x12e(r1)"),
    0x29610: ("lhz", "r29,0x130(r1)"),
    0x2960c: ("lhz", "r6,0x132(r1)"),
    0x29608: ("lhz", "r7,0x134(r1)"),

    0x2982c: ("add", "r0,r19,r25"),
    0x29830: ("addi", "r11,r1,0x1b0"),
    0x29840: ("rlwinm", "r2,r0,1,0,30"),
    0x29844: ("rlwinm", "r24,r0,2,0,29"),
    0x29850: ("add", "r2,r2,r11"),
    0x29854: ("add", "r9,r24,r11"),
    0x29858: ("lhz", "r11,0xffac(r2)"),
    0x2985c: ("lhz", "r8,0xffbe(r2)"),
    0x29860: ("lwz", "r2,0xff88(r9)"),
}

DIRECT_HALFWORD_OFFSETS = [
    0x00, 0x02, 0x04, 0x06, 0x08, 0x0a, 0x0c, 0x0e,
    0x10, 0x12, 0x14, 0x16, 0x18, 0x1a, 0x1c,
]

TARGETS = [
    ("disabled-clear", ("titlebarcontrols", "close", "colorsryg", "disabled", "regularwin")),
    ("disabled-minus", ("titlebarcontrols", "colorsryg", "disabled", "minimize", "regularwin")),
    ("disabled-zoom", ("titlebarcontrols", "colorsryg", "disabled", "regularwin", "zoom")),
    ("active-clear", ("titlebarcontrols", "active", "close", "colorsryg", "regularwin")),
    ("active-minus", ("titlebarcontrols", "active", "colorsryg", "minimize", "regularwin")),
    ("active-zoom", ("titlebarcontrols", "active", "colorsryg", "regularwin", "zoom")),
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


def byte_value(ch):
    return ch if isinstance(ch, int) else ord(ch)


def u16(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def s16(data, off):
    return struct.unpack("<h", data[off:off + 2])[0]


def u32(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def hex_bytes(data):
    return "".join("%02x" % byte_value(ch) for ch in data)


def make_bytes(values):
    return "".join(chr(value) for value in values)


def cstring(data, off, limit=512):
    if off < 0 or off >= len(data):
        return None
    chars = []
    for pos in range(off, min(len(data), off + limit)):
        value = byte_value(data[pos])
        if value == 0:
            return "".join(chars)
        if value < 0x20 or value > 0x7e:
            return None
        chars.append(chr(value))
    return None


def parse_header(data):
    if len(data) < 24:
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


def parse_dictionary(data, header):
    byname = {}
    for ident in range(1, header["component_count"] + 1):
        ent = header["table_start"] + (ident - 1) * 8
        if ent + 8 > header["string_pool"] or ent + 8 > len(data):
            continue
        name = cstring(data, header["string_pool"] + u32(data, ent))
        if name is not None and name not in byname:
            byname[name] = ident
    return byname


def parse_index(data, header):
    rows = []
    size = header["path_len"] + 4
    for index in range(header["record_count"]):
        off = header["index_start"] + index * size
        if off + size > len(data):
            break
        rel = u32(data, off)
        rows.append(dict(
            index=index,
            record_off=off,
            payload_rel=rel,
            payload_off=header["payload_start"] + rel,
            key=data[off + 4:off + size],
        ))
    return rows


def encode_semantic(parts, byname, path_len):
    ids = []
    for part in parts:
        ident = byname.get(part)
        if ident is None or ident > 255:
            return None
        ids.append(ident)
    if len(ids) > path_len:
        return None
    return make_bytes(ids + [0] * (path_len - len(ids)))


def parse_hex_token(token):
    token = token.rstrip(":")
    if token.startswith("0x") or token.startswith("0X"):
        token = token[2:]
    if not token:
        return None
    for char in token:
        if char not in "0123456789abcdefABCDEF":
            return None
    try:
        return int(token, 16)
    except ValueError:
        return None


def parse_disassembly(text):
    rows = {}
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows[addr] = line
    return rows


def parse_symbols(text):
    result = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in line:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        if name not in result:
            result[name] = addr
    return result


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True
    rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0


def thin_arch(src, arch, dst):
    if not verify_arch(src, arch):
        return False
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0


def verify_loader_code(tmpdir, issues):
    fields = {}
    if not os.path.isfile(COREUI):
        issues.append("Snow CoreUI binary missing")
        return fields

    whole_sha = sha256(COREUI)
    fields["coreui_sha256"] = whole_sha
    if whole_sha != EXPECTED_SNOW_COREUI_SHA256:
        issues.append("Snow CoreUI whole-file SHA mismatch")

    thin = os.path.join(tmpdir, "CoreUI.ppc7400")
    if not thin_arch(COREUI, "ppc7400", thin):
        issues.append("Snow CoreUI ppc7400 slice unavailable")
        return fields

    slice_sha = sha256(thin)
    fields["ppc_slice_sha256"] = slice_sha
    if slice_sha != EXPECTED_SNOW_COREUI_PPC_SHA256:
        issues.append("Snow CoreUI PPC slice SHA mismatch")

    rc, nm = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        issues.append("nm -nm failed")
        return fields
    symbols = parse_symbols(nm)
    addr = symbols.get(LOAD_FROM_ARTFILE)
    fields["load_from_artfile_address"] = addr
    if addr != EXPECTED_LOAD_FROM_ARTFILE:
        issues.append("Snow LoadFromArtFile symbol address mismatch")

    rc, dis = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        issues.append("otool disassembly failed")
        return fields
    rows = parse_disassembly(dis)

    instruction_ok = True
    observed = []
    for addr in sorted(EXPECTED_INSTRUCTIONS.keys()):
        mnemonic, operand = EXPECTED_INSTRUCTIONS[addr]
        line = rows.get(addr)
        observed.append((addr, line))
        if line is None or mnemonic not in line:
            instruction_ok = False
            continue
        if operand is not None and operand.replace(" ", "") not in line.replace(" ", ""):
            instruction_ok = False
    fields["instruction_rows"] = observed
    fields["instruction_contract"] = instruction_ok
    if not instruction_ok:
        issues.append("Snow LoadFromArtFile field-access instruction contract mismatch")

    # 0x136(r1) is copied as part of the 0x68-byte header but is not one
    # of the fixed halfword loads used to populate the element metrics.
    direct_1e = any("0x136(r1)" in line for line in rows.values())
    fields["direct_halfword_0x1e_observed"] = direct_1e
    if direct_1e:
        issues.append("unexpected direct read of header halfword 0x1e")

    return fields


def verify_release(data, product, expected, issues):
    if len(data) != expected["art_size"]:
        issues.append("ArtFile size mismatch")
    digest = sha256(ARTFILE)
    if digest != expected["art_sha256"]:
        issues.append("ArtFile SHA mismatch")

    header = parse_header(data)
    if header is None:
        issues.append("ArtFile header unavailable")
        return None, [], {}

    for key in ("record_count", "path_len", "component_count", "table_start",
                "string_pool", "index_start", "payload_start"):
        if header.get(key) != expected[key]:
            issues.append("ArtFile header %s mismatch" % key)

    byname = parse_dictionary(data, header)
    records = parse_index(data, header)
    if len(records) != header["record_count"]:
        issues.append("ArtFile index record count mismatch")
    return header, records, byname


def record_spans(data, records):
    starts = sorted(set(
        rec["payload_off"] for rec in records
        if 0 <= rec["payload_off"] <= len(data)))
    next_by_start = {}
    for index, start in enumerate(starts):
        next_by_start[start] = starts[index + 1] if index + 1 < len(starts) else len(data)
    return next_by_start


def decode_old_loader_record(span):
    if len(span) < 0x68:
        return None
    count0 = u16(span, 0x00)
    count1 = u16(span, 0x02)
    metrics = [s16(span, off) for off in range(0x04, 0x1e, 2)]
    raw_1e = u16(span, 0x1e)
    cell_count = count0 * count1

    cells = []
    arrays_fit = True
    for cell in range(cell_count):
        off_pos = 0x20 + cell * 4
        width_pos = 0x44 + cell * 2
        height_pos = 0x56 + cell * 2
        if off_pos + 4 > 0x68 or width_pos + 2 > 0x68 or height_pos + 2 > 0x68:
            arrays_fit = False
            break
        body_off = u32(span, off_pos)
        width = u16(span, width_pos)
        height = u16(span, height_pos)
        body_bytes = width * height * 4
        cells.append(dict(
            index=cell,
            body_offset=body_off,
            width=width,
            height=height,
            body_bytes=body_bytes,
            end=body_off + body_bytes,
        ))

    exact_end = bool(cells) and max(cell["end"] for cell in cells) == len(span)
    body_offsets_valid = all(
        cell["body_offset"] >= 0x68 and cell["body_offset"] <= len(span)
        for cell in cells)
    dimensions_valid = all(
        cell["width"] > 0 and cell["height"] > 0
        for cell in cells)

    return dict(
        count0=count0,
        count1=count1,
        cell_count=cell_count,
        metrics=metrics,
        raw_1e=raw_1e,
        cells=cells,
        arrays_fit=arrays_fit,
        exact_end=exact_end,
        body_offsets_valid=body_offsets_valid,
        dimensions_valid=dimensions_valid,
    )


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./ppc-carbon-gui-artfile-snow-loader-field-contract.txt"
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-artfile-loader-fields.")

    try:
        rc, out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = out.strip() if rc == 0 else "UNKNOWN"
        rc, out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = out.strip() if rc == 0 else "UNKNOWN"

        expected = EXPECTED.get(product)
        if expected is None:
            expected = EXPECTED["10.7.5"]
            issues.append("unsupported product version: %s" % product)
        elif build != expected["build"]:
            issues.append("unexpected build version")

        cache_sha = sha256(ROSETTA_CACHE) if os.path.isfile(ROSETTA_CACHE) else "MISSING"
        map_sha = sha256(ROSETTA_MAP) if os.path.isfile(ROSETTA_MAP) else "MISSING"
        cache_ok = cache_sha == EXPECTED_CACHE_SHA256
        map_ok = map_sha == EXPECTED_CACHE_MAP_SHA256
        if not cache_ok:
            issues.append("Rosetta shared cache SHA mismatch")
        if not map_ok:
            issues.append("Rosetta shared cache map SHA mismatch")

        map_coreui = False
        if os.path.isfile(ROSETTA_MAP):
            try:
                map_text = open(ROSETTA_MAP, "r").read()
            except IOError:
                map_text = ""
            map_coreui = COREUI in map_text
        if not map_coreui:
            issues.append("CoreUI missing from Rosetta cache map")

        loader_fields = {}
        if product == "10.6.8":
            loader_fields = verify_loader_code(tmpdir, issues)
        elif product == "10.7.5":
            if os.path.isfile(COREUI) and verify_arch(COREUI, "ppc7400"):
                issues.append("Lion on-disk CoreUI unexpectedly contains ppc7400")

        if not os.path.isfile(ARTFILE):
            data = ""
            issues.append("ArtFile.bin missing")
        else:
            data = open(ARTFILE, "rb").read()

        header, records, byname = verify_release(data, product, expected, issues)
        next_by_start = record_spans(data, records)

        decoded_rows = []
        exact_layout_count = 0
        if header is not None:
            for target_name, semantic in TARGETS:
                key = encode_semantic(semantic, byname, header["path_len"])
                hits = [rec for rec in records if key is not None and rec["key"] == key]
                if key is None:
                    issues.append("semantic key unresolved: %s" % target_name)
                if len(hits) != 1:
                    issues.append("exact-six hit count mismatch: %s" % target_name)
                    continue

                rec = hits[0]
                start = rec["payload_off"]
                end = next_by_start.get(start, len(data))
                if start < 0 or end < start or end > len(data):
                    issues.append("invalid payload span: %s" % target_name)
                    continue
                span = data[start:end]
                decoded = decode_old_loader_record(span)
                if decoded is None:
                    issues.append("payload shorter than Snow loader header: %s" % target_name)
                    continue

                layout_exact = (
                    decoded["cell_count"] == 1 and
                    decoded["arrays_fit"] and
                    decoded["body_offsets_valid"] and
                    decoded["dimensions_valid"] and
                    len(decoded["cells"]) == 1 and
                    decoded["cells"][0]["body_offset"] == 0x68 and
                    decoded["exact_end"]
                )
                if layout_exact:
                    exact_layout_count += 1
                else:
                    issues.append("old-loader 1x1 cell contract mismatch: %s" % target_name)

                decoded_rows.append((target_name, semantic, key, rec, span, decoded, layout_exact))

        if exact_layout_count != 6:
            issues.append("exact-six old-loader cell-contract count mismatch")

        with open(report, "w") as fp:
            write_line(fp, "== PPC Carbon GUI Snow-loader ArtFile field-contract audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)

            write_line(fp)
            write_line(fp, "== Runtime PPC loader provenance ==")
            write_line(fp, "rosetta_cache_sha256=%s" % cache_sha)
            write_line(fp, "rosetta_cache_expected=%s" % ("YES" if cache_ok else "NO"))
            write_line(fp, "rosetta_cache_map_sha256=%s" % map_sha)
            write_line(fp, "rosetta_cache_map_expected=%s" % ("YES" if map_ok else "NO"))
            write_line(fp, "coreui_present_in_rosetta_cache_map=%s" % ("YES" if map_coreui else "NO"))
            if product == "10.6.8":
                write_line(fp, "snow_coreui_sha256=%s" % loader_fields.get("coreui_sha256", "MISSING"))
                write_line(fp, "snow_coreui_ppc_slice_sha256=%s" % loader_fields.get("ppc_slice_sha256", "MISSING"))
                address = loader_fields.get("load_from_artfile_address")
                write_line(fp, "loadfromartfile_address=%s" %
                           (("0x%x" % address) if address is not None else "MISSING"))
                write_line(fp, "snow_loader_instruction_contract=%s" %
                           ("PASS" if loader_fields.get("instruction_contract") else "FAIL"))
                write_line(fp, "header_copy_length=0x68")
                write_line(fp, "header_copy_stack_base=0x118")
                write_line(fp, "direct_halfword_offsets=" +
                           ",".join("0x%02x" % off for off in DIRECT_HALFWORD_OFFSETS))
                write_line(fp, "direct_halfword_0x1e_observed=%s" %
                           ("YES" if loader_fields.get("direct_halfword_0x1e_observed") else "NO"))
                write_line(fp, "cell_data_offset_array_base=0x20")
                write_line(fp, "cell_width_array_base=0x44")
                write_line(fp, "cell_height_array_base=0x56")
            else:
                write_line(fp, "runtime_ppc_loader_source=dyld_shared_cache_rosetta")
                write_line(fp, "runtime_ppc_loader_contract=accepted_identical_snow_ppc_cache")
                write_line(fp, "header_copy_length=0x68")
                write_line(fp, "direct_halfword_offsets=" +
                           ",".join("0x%02x" % off for off in DIRECT_HALFWORD_OFFSETS))
                write_line(fp, "cell_data_offset_array_base=0x20")
                write_line(fp, "cell_width_array_base=0x44")
                write_line(fp, "cell_height_array_base=0x56")

            write_line(fp)
            write_line(fp, "== Local ArtFile identity ==")
            write_line(fp, "artfile_size=%d" % len(data))
            write_line(fp, "artfile_sha256=%s" % (sha256(ARTFILE) if os.path.isfile(ARTFILE) else "MISSING"))
            if header is not None:
                write_line(fp, "record_count=%d" % header["record_count"])
                write_line(fp, "path_len=%d" % header["path_len"])
                write_line(fp, "component_count=%d" % header["component_count"])
                write_line(fp, "index_start=0x%x" % header["index_start"])
                write_line(fp, "payload_start=0x%x" % header["payload_start"])

            write_line(fp)
            write_line(fp, "== Exact-six records decoded by Snow PPC loader contract ==")
            for target_name, semantic, key, rec, span, decoded, layout_exact in decoded_rows:
                write_line(fp, "path=%s" % target_name)
                write_line(fp, "semantic_path=%s" % ".".join(semantic))
                write_line(fp, "local_key=%s" % hex_bytes(key))
                write_line(fp, "index=%d" % rec["index"])
                write_line(fp, "payload_off=0x%x" % rec["payload_off"])
                write_line(fp, "payload_span_length=%d" % len(span))
                write_line(fp, "count0=%d" % decoded["count0"])
                write_line(fp, "count1=%d" % decoded["count1"])
                write_line(fp, "cell_count=%d" % decoded["cell_count"])
                write_line(fp, "metric_s16_0x04_to_0x1c=" +
                           ",".join(str(value) for value in decoded["metrics"]))
                write_line(fp, "raw_u16_0x1e=0x%04x" % decoded["raw_1e"])
                for cell in decoded["cells"]:
                    write_line(fp, "cell%d_body_offset=0x%x" % (cell["index"], cell["body_offset"]))
                    write_line(fp, "cell%d_width=%d" % (cell["index"], cell["width"]))
                    write_line(fp, "cell%d_height=%d" % (cell["index"], cell["height"]))
                    write_line(fp, "cell%d_body_bytes=%d" % (cell["index"], cell["body_bytes"]))
                    write_line(fp, "cell%d_end=%d" % (cell["index"], cell["end"]))
                write_line(fp, "old_loader_1x1_record_exact=%s" %
                           ("YES" if layout_exact else "NO"))
                write_line(fp)

            write_line(fp, "exact_six_old_loader_record_count=%d" % len(decoded_rows))
            write_line(fp, "exact_six_old_loader_cell_contract_count=%d" % exact_layout_count)

            write_line(fp)
            write_line(fp, "== Decision inputs ==")
            write_line(fp, "field_0x1e_directly_consumed_by_pinned_snow_loader=NO")
            write_line(fp, "record_body_address_source=header_u32_array_at_0x20")
            write_line(fp, "record_width_source=header_u16_array_at_0x44")
            write_line(fp, "record_height_source=header_u16_array_at_0x56")
            write_line(fp, "next_if_both_reports_pass=review_release_metric_deltas_before_any_field_adapter")

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "old_loader_field_contract_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No process was attached.")
            write_line(fp, "No compatibility dylib was built or loaded.")
            write_line(fp, "No framework, ArtFile resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
            write_line(fp, "Temporary Snow CoreUI architecture slices, when needed, were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        if issues:
            print("RESULT: FAIL")
            for issue in issues:
                print("validation_issue=%s" % issue)
            return 1
        print("RESULT: PASS")
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
