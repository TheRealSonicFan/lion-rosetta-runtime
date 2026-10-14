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
AUDIT_CONTRACT = "carbon-gui-artfile-render-state-contract-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        coreui_slice_sha256="5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        art_size=5946480,
        art_sha256="1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        record_count=3324,
        path_len=8,
        component_count=182,
        index_start=0xc4a,
        payload_start=0xa81c,
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        coreui_slice_sha256="5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        art_size=4765184,
        art_sha256="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        record_count=2674,
        path_len=8,
        component_count=169,
        index_start=0xb9d,
        payload_start=0x88f8,
    ),
}

TARGETS = [
    ("disabled-clear", ("titlebarcontrols", "close", "colorsryg", "disabled", "regularwin")),
    ("disabled-minus", ("titlebarcontrols", "colorsryg", "disabled", "minimize", "regularwin")),
    ("disabled-zoom", ("titlebarcontrols", "colorsryg", "disabled", "regularwin", "zoom")),
    ("active-clear", ("titlebarcontrols", "active", "close", "colorsryg", "regularwin")),
    ("active-minus", ("titlebarcontrols", "active", "colorsryg", "minimize", "regularwin")),
    ("active-zoom", ("titlebarcontrols", "active", "colorsryg", "regularwin", "zoom")),
]

# The preceding field-contract audit already proved the serialized source offsets.
# This audit proves where those metrics land in CUIElement and the image-constructor
# contract used by each release-local CoreUI implementation.
METRIC_SOURCE_OFFSETS = [
    0x04, 0x06, 0x08, 0x0a,
    0x0c, 0x0e, 0x10, 0x12,
    0x14, 0x16, 0x18, 0x1a,
    0x1c,
]
ELEMENT_DEST_OFFSETS = [
    0x10, 0x14, 0x18, 0x1c,
    0x20, 0x24, 0x28, 0x2c,
    0x30, 0x34, 0x38, 0x3c,
    0x40,
]

SNOW_REQUIRED = {
    0x29530: ("li", "r5,0x68"),
    0x296e8: ("stfs", "f0,0x10(r21)"),
    0x296ec: ("stfs", "f13,0x14(r21)"),
    0x29738: ("stfs", "f11,0x18(r21)"),
    0x2973c: ("stfs", "f12,0x1c(r21)"),
    0x297cc: ("stfs", "f9,0x20(r21)"),
    0x29744: ("stfs", "f10,0x24(r21)"),
    0x29740: ("stfs", "f13,0x28(r21)"),
    0x29748: ("stfs", "f0,0x2c(r21)"),
    0x29818: ("stfs", "f11,0x30(r21)"),
    0x2981c: ("stfs", "f12,0x34(r21)"),
    0x29820: ("stfs", "f13,0x38(r21)"),
    0x29824: ("stfs", "f0,0x3c(r21)"),
    0x29814: ("stfs", "f10,0x40(r21)"),
    0x29834: ("lbz", "r7,0x4b3c(r16)"),
    0x29898: ("beq", "0x2990c"),
    0x298bc: ("li", "r0,0x1881"),
    0x298f0: ("_CWMatchBitmap", None),
    0x2995c: ("_CGDataProviderCreateDirect", None),
    0x29960: ("li", "r9,0x4"),
    0x2997c: ("_CGDataProviderCreateWithData", None),
    0x29980: ("li", "r9,0x2"),
    0x299bc: ("li", "r5,0x8"),
    0x299c0: ("li", "r6,0x20"),
    0x299dc: ("_CGImageCreate", None),
}

LION_REQUIRED = {
    0x3ca70: ("movl", "$0x0000001a,%ecx"),
    0x3ca7b: ("rep/movsl", None),
    0x3caba: ("movss", "0x10(%ebx)"),
    0x3cac3: ("movss", "0x14(%ebx)"),
    0x3cacc: ("movss", "0x18(%ebx)"),
    0x3cad5: ("movss", "0x1c(%ebx)"),
    0x3cafa: ("movss", "0x20(%ebx)"),
    0x3cb03: ("movss", "0x24(%ebx)"),
    0x3cb0c: ("movss", "0x28(%ebx)"),
    0x3cb15: ("movss", "0x2c(%ebx)"),
    0x3cb34: ("movss", "0x30(%ebx)"),
    0x3cb3d: ("movss", "0x34(%ebx)"),
    0x3cb46: ("movss", "0x38(%ebx)"),
    0x3cb4f: ("movss", "0x3c(%ebx)"),
    0x3cb5c: ("movss", "0x40(%ebx)"),
    0x3cc65: ("_CGDataProviderCreateWithData", None),
    0x3cce4: ("movl", "$0x00002002,0x18(%esp)"),
    0x3ccec: ("movl", "$0x00000020,0x0c(%esp)"),
    0x3ccf4: ("movl", "$0x00000008,0x08(%esp)"),
    0x3ccfc: ("_CGImageCreate", None),
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


def byte_value(ch):
    return ch if isinstance(ch, int) else ord(ch)


def u16(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def s16(data, off):
    return struct.unpack("<h", data[off:off + 2])[0]


def u32(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def make_bytes(values):
    return "".join(chr(value) for value in values)


def hex_bytes(data):
    return "".join("%02x" % byte_value(ch) for ch in data)


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
    for ch in token:
        if ch not in "0123456789abcdefABCDEF":
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


def verify_instruction_contract(rows, required):
    observed = []
    ok = True
    for addr in sorted(required.keys()):
        mnemonic, operand = required[addr]
        line = rows.get(addr)
        observed.append((addr, line))
        if line is None or mnemonic not in line:
            ok = False
            continue
        if operand is not None and operand.replace(" ", "") not in line.replace(" ", ""):
            ok = False
    return ok, observed


def pixel_model(body, alpha_index):
    violations = 0
    zero_alpha_with_color = 0
    nonzero_alpha = 0
    opaque_alpha = 0
    pixels = len(body) // 4
    for index in range(pixels):
        px = [byte_value(body[index * 4 + j]) for j in range(4)]
        alpha = px[alpha_index]
        colors = [px[j] for j in range(4) if j != alpha_index]
        if alpha != 0:
            nonzero_alpha += 1
        if alpha == 255:
            opaque_alpha += 1
        if alpha == 0 and any(value != 0 for value in colors):
            zero_alpha_with_color += 1
        if any(value > alpha for value in colors):
            violations += 1
    return dict(
        pixels=pixels,
        premul_violations=violations,
        zero_alpha_with_color=zero_alpha_with_color,
        nonzero_alpha=nonzero_alpha,
        opaque_alpha=opaque_alpha,
    )


def preferred_alpha(model0, model3):
    score0 = model0["premul_violations"] + model0["zero_alpha_with_color"]
    score3 = model3["premul_violations"] + model3["zero_alpha_with_color"]
    if score0 < score3:
        return "BYTE0"
    if score3 < score0:
        return "BYTE3"
    return "AMBIGUOUS"


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./ppc-carbon-gui-artfile-render-state.txt"
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-artfile-render-state.")

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

        if not os.path.isfile(ARTFILE):
            data = ""
            issues.append("ArtFile.bin missing")
        else:
            data = open(ARTFILE, "rb").read()

        if len(data) != expected["art_size"]:
            issues.append("ArtFile size mismatch")
        art_sha = sha256(ARTFILE) if os.path.isfile(ARTFILE) else "MISSING"
        if art_sha != expected["art_sha256"]:
            issues.append("ArtFile SHA mismatch")

        header = parse_header(data)
        if header is None:
            issues.append("ArtFile header unavailable")
            records = []
            byname = {}
        else:
            for key in ("record_count", "path_len", "component_count", "index_start", "payload_start"):
                if header.get(key) != expected[key]:
                    issues.append("ArtFile header mismatch: %s" % key)
            records = parse_index(data, header)
            byname = parse_dictionary(data, header)
            if len(records) != header["record_count"]:
                issues.append("ArtFile index count mismatch")

        coreui_contract = False
        rows = {}
        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
            coreui_sha = "MISSING"
        else:
            thin = os.path.join(tmpdir, "CoreUI.%s" % expected["arch"])
            if not thin_arch(COREUI, expected["arch"], thin):
                issues.append("CoreUI required slice unavailable")
                coreui_sha = "MISSING"
            else:
                coreui_sha = sha256(thin)
                if coreui_sha != expected["coreui_slice_sha256"]:
                    issues.append("CoreUI slice SHA mismatch")
                rc, dis = run(["/usr/bin/otool", "-tvV", thin])
                if rc != 0:
                    issues.append("CoreUI disassembly failed")
                else:
                    rows = parse_disassembly(dis)
                    required = SNOW_REQUIRED if product == "10.6.8" else LION_REQUIRED
                    coreui_contract, observed = verify_instruction_contract(rows, required)
                    if not coreui_contract:
                        issues.append("CoreUI render-state/image-constructor instruction contract mismatch")

        decoded = []
        preferred_counts = {"BYTE0": 0, "BYTE3": 0, "AMBIGUOUS": 0}
        if header is not None:
            for target_name, semantic in TARGETS:
                key = encode_semantic(semantic, byname, header["path_len"])
                hits = [row for row in records if key is not None and row["key"] == key]
                if len(hits) != 1:
                    issues.append("exact-six hit count mismatch: %s" % target_name)
                    continue
                rec = hits[0]
                start = rec["payload_off"]
                if start < 0 or start + 0x68 > len(data):
                    issues.append("record header out of bounds: %s" % target_name)
                    continue

                count0 = u16(data, start + 0x00)
                count1 = u16(data, start + 0x02)
                metrics = [s16(data, start + off) for off in METRIC_SOURCE_OFFSETS]
                body_off = u32(data, start + 0x20)
                width = u16(data, start + 0x44)
                height = u16(data, start + 0x56)
                body_len = width * height * 4
                body_start = start + body_off
                body_end = body_start + body_len
                if count0 != 1 or count1 != 1:
                    issues.append("exact-six cell count is not 1x1: %s" % target_name)
                if body_off != 0x68:
                    issues.append("exact-six body offset is not 0x68: %s" % target_name)
                if body_end > len(data):
                    issues.append("exact-six image body out of bounds: %s" % target_name)
                    continue

                body = data[body_start:body_end]
                model0 = pixel_model(body, 0)
                model3 = pixel_model(body, 3)
                pref = preferred_alpha(model0, model3)
                preferred_counts[pref] += 1
                center_index = ((height // 2) * width + (width // 2)) * 4
                center = body[center_index:center_index + 4] if center_index + 4 <= len(body) else ""
                decoded.append(dict(
                    name=target_name,
                    semantic=semantic,
                    key=key,
                    index=rec["index"],
                    metrics=metrics,
                    body_off=body_off,
                    width=width,
                    height=height,
                    body_len=body_len,
                    body_sha=hashlib.sha256(body).hexdigest(),
                    center=center,
                    model0=model0,
                    model3=model3,
                    preferred=pref,
                ))

        if len(decoded) != 6:
            issues.append("exact-six decoded record count mismatch")

        with open(report, "w") as fp:
            write_line(fp, "== PPC Carbon GUI ArtFile render-state/image-format audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)

            write_line(fp)
            write_line(fp, "== Local identities ==")
            write_line(fp, "artfile_size=%d" % len(data))
            write_line(fp, "artfile_sha256=%s" % art_sha)
            write_line(fp, "coreui_required_arch=%s" % expected["arch"])
            write_line(fp, "coreui_slice_sha256=%s" % coreui_sha)
            write_line(fp, "coreui_instruction_contract=%s" % ("PASS" if coreui_contract else "FAIL"))

            write_line(fp)
            write_line(fp, "== Serialized metric -> CUIElement state contract ==")
            write_line(fp, "metric_source_offsets=" + ",".join("0x%02x" % off for off in METRIC_SOURCE_OFFSETS))
            write_line(fp, "element_destination_offsets=" + ",".join("0x%02x" % off for off in ELEMENT_DEST_OFFSETS))
            write_line(fp, "rect0_source=0x04,0x06,0x08,0x0a")
            write_line(fp, "rect0_destination=element+0x10,+0x14,+0x18,+0x1c")
            write_line(fp, "rect1_source=0x0c,0x0e,0x10,0x12")
            write_line(fp, "rect1_destination=element+0x20,+0x24,+0x28,+0x2c")
            write_line(fp, "rect2_source=0x14,0x16,0x18,0x1a")
            write_line(fp, "rect2_destination=element+0x30,+0x34,+0x38,+0x3c")
            write_line(fp, "scalar_source=0x1c")
            write_line(fp, "scalar_destination=element+0x40")
            if product == "10.6.8":
                write_line(fp, "metric_decode_kind=SIGNED_16_TO_FLOAT")
                write_line(fp, "image_constructor_provider_paths=CGDataProviderCreateDirect|CGDataProviderCreateWithData")
                write_line(fp, "image_constructor_bitmapinfo_values=0x00000004|0x00000002")
                write_line(fp, "image_constructor_byte_order_mask=DEFAULT")
                write_line(fp, "image_constructor_matchbitmap_branch=PRESENT")
                write_line(fp, "image_constructor_matchbitmap_tag=0x1881")
            else:
                write_line(fp, "metric_decode_kind=UNSIGNED_16_TO_FLOAT")
                write_line(fp, "image_constructor_provider_paths=CGDataProviderCreateWithData")
                write_line(fp, "image_constructor_bitmapinfo_values=0x00002002")
                write_line(fp, "image_constructor_byte_order_mask=32_LITTLE")
                write_line(fp, "image_constructor_matchbitmap_branch=ABSENT")

            write_line(fp)
            write_line(fp, "== Exact-six render state and raw image-body channel diagnostics ==")
            for row in decoded:
                write_line(fp, "path=%s" % row["name"])
                write_line(fp, "semantic_path=%s" % ".".join(row["semantic"]))
                write_line(fp, "local_key=%s" % hex_bytes(row["key"]))
                write_line(fp, "index=%d" % row["index"])
                metrics = row["metrics"]
                write_line(fp, "metric_s16_0x04_to_0x1c=" + ",".join(str(v) for v in metrics))
                write_line(fp, "rect0=%d,%d,%d,%d" % tuple(metrics[0:4]))
                write_line(fp, "rect1=%d,%d,%d,%d" % tuple(metrics[4:8]))
                write_line(fp, "rect2=%d,%d,%d,%d" % tuple(metrics[8:12]))
                write_line(fp, "scalar=%d" % metrics[12])
                write_line(fp, "cell0_body_offset=0x%x" % row["body_off"])
                write_line(fp, "cell0_width=%d" % row["width"])
                write_line(fp, "cell0_height=%d" % row["height"])
                write_line(fp, "cell0_body_bytes=%d" % row["body_len"])
                write_line(fp, "cell0_body_sha256=%s" % row["body_sha"])
                write_line(fp, "center_pixel_raw=%s" % hex_bytes(row["center"]))
                m0 = row["model0"]
                m3 = row["model3"]
                write_line(fp, "alpha_byte0_premul_violations=%d" % m0["premul_violations"])
                write_line(fp, "alpha_byte0_zero_with_color=%d" % m0["zero_alpha_with_color"])
                write_line(fp, "alpha_byte0_nonzero=%d" % m0["nonzero_alpha"])
                write_line(fp, "alpha_byte0_opaque=%d" % m0["opaque_alpha"])
                write_line(fp, "alpha_byte3_premul_violations=%d" % m3["premul_violations"])
                write_line(fp, "alpha_byte3_zero_with_color=%d" % m3["zero_alpha_with_color"])
                write_line(fp, "alpha_byte3_nonzero=%d" % m3["nonzero_alpha"])
                write_line(fp, "alpha_byte3_opaque=%d" % m3["opaque_alpha"])
                write_line(fp, "raw_body_preferred_alpha_byte=%s" % row["preferred"])
                write_line(fp)

            write_line(fp, "preferred_alpha_byte0_count=%d" % preferred_counts["BYTE0"])
            write_line(fp, "preferred_alpha_byte3_count=%d" % preferred_counts["BYTE3"])
            write_line(fp, "preferred_alpha_ambiguous_count=%d" % preferred_counts["AMBIGUOUS"])

            write_line(fp)
            write_line(fp, "== Decision inputs ==")
            write_line(fp, "metric_layout_grouping_shared=YES")
            write_line(fp, "snow_bitmapinfo_default_byte_order=YES" if product == "10.6.8" else "snow_bitmapinfo_default_byte_order=NOT_LOCAL_RELEASE")
            write_line(fp, "lion_native_bitmapinfo_0x2002=YES" if product == "10.7.5" else "lion_native_bitmapinfo_0x2002=NOT_LOCAL_RELEASE")
            write_line(fp, "next_if_reports_show_release_specific_alpha_position=prepare_live_coreui_image_constructor_trace")
            write_line(fp, "next_if_alpha_position_not_release_specific=review_metric_rect_deltas_in_downstream_renderer")

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "render_state_image_contract_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No process was attached.")
            write_line(fp, "No compatibility dylib was built or loaded.")
            write_line(fp, "No framework, ArtFile resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
            write_line(fp, "Temporary CoreUI architecture slices were created only under the system temporary directory and removed on exit.")

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
