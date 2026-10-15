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
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-frame-id-relocation-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
SARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"
DRAW_FRAME = "__ZN11CUIRenderer19DrawWindowFrameDarkEPK13CUIDescriptor"

LEGACY_TO_LION = [
    (0x4e8e, 0x4e76),
    (0x4e90, 0x4e78),
    (0x4e8d, 0x4e75),
    (0x4e8f, 0x4e77),
    (0x4e91, 0x4e79),
]

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        coreui_sha="5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        sart_size=811436,
        sart_sha="62eb745beaafa0a24111c0ac3b3452cebfda4aeec5e56e51b054ae2d62f778b2",
        count=237,
        target_ids=[x[0] for x in LEGACY_TO_LION],
        expected_type_count=(2, 1),
        expected_callee="CreateImageElPK13CUIDescriptorP6CGRectPfPtPh",
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        coreui_sha="5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        sart_size=9370228,
        sart_sha="29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b",
        count=348,
        target_ids=[x[1] for x in LEGACY_TO_LION],
        expected_type_count=(1, 2),
        expected_callee="CreateInternalImageWithScaleElPK13CUIDescriptorP6CGRect",
    ),
}

SART_BASE = 0x4e20
TABLE_BASE = 0x08
TABLE_STRIDE = 4
SLOT_STRIDE = 0x0c
WIDTH_OFF = 0x0c
HEIGHT_OFF = 0x0e
LENGTH_OFF = 0x10
DATA_OFF = 0x14

ANCHOR_HASHES = {
    0x4e75: "9577c7876e34e40a778511795c7a28702af3613dca28b5edeac5f6972ff9912e",
    0x4e76: "44897e71f9f949fa7b276adc71a2d58c02ebaab80721ac0035d113fd9f37288f",
    0x4e78: "ba825c44fbcb9a52febacfdd60c29383b3a9fb83d3740789f434e28b1cbf1cd7",
}


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha_file(path):
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


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def u16(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def parse_hex(token):
    token = token.rstrip(":")
    if token.startswith("0x") or token.startswith("0X"):
        token = token[2:]
    if not token:
        return None
    try:
        return int(token, 16)
    except ValueError:
        return None


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True
    rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0


def thin(src, arch, dst):
    if not verify_arch(src, arch):
        return False
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0


def parse_symbols(text):
    ordered = []
    by_name = {}
    for raw in text.splitlines():
        parts = raw.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in raw:
            continue
        addr = parse_hex(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        if name not in by_name:
            by_name[name] = addr
    ordered.sort()
    return ordered, by_name


def parse_rows(text):
    rows = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex(parts[0])
        if addr is not None:
            rows.append((addr, raw))
    return rows


def symbol_body(symbols, rows, name):
    idx = None
    for i, item in enumerate(symbols):
        if item[1] == name:
            idx = i
            break
    if idx is None:
        return None, []
    start = symbols[idx][0]
    end = symbols[idx + 1][0] if idx + 1 < len(symbols) else None
    return start, [(addr, raw) for addr, raw in rows
                   if addr >= start and (end is None or addr < end)]


def target_hits(body, target_ids, expected_callee):
    hits = []
    for i, (addr, raw) in enumerate(body):
        low = raw.lower()
        matched = None
        for image_id in target_ids:
            token = "0x%04x" % image_id
            token8 = "0x%08x" % image_id
            if token in low or token8 in low:
                matched = image_id
                break
        if matched is None:
            continue
        call_addr = None
        call_raw = None
        callee_ok = False
        for j in range(i + 1, min(len(body), i + 12)):
            candidate = body[j][1]
            if "\tbl\t" in candidate or "\tcalll\t" in candidate:
                call_addr = body[j][0]
                call_raw = candidate
                callee_ok = expected_callee in candidate
                break
        hits.append(dict(
            image_id=matched,
            const_addr=addr,
            const_raw=raw,
            call_addr=call_addr,
            call_raw=call_raw,
            callee_ok=callee_ok,
        ))
    unique = []
    seen = set()
    for item in hits:
        key = (item["image_id"], item["const_addr"])
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique


def read_record(data, count, image_id, data_base):
    index = image_id - SART_BASE
    table_off = TABLE_BASE + index * TABLE_STRIDE
    if index <= 0 or index >= count or table_off + 4 > len(data):
        return None
    header_off = u32(data, table_off)
    if header_off <= 0 or header_off + 4 > len(data):
        return None
    image_type = u16(data, header_off)
    entry_count = u16(data, header_off + 2)
    slots = []
    for slot in range(min(entry_count, 8)):
        base = header_off + slot * SLOT_STRIDE
        if base + DATA_OFF + 4 > len(data):
            break
        width = u16(data, base + WIDTH_OFF)
        height = u16(data, base + HEIGHT_OFF)
        length = u32(data, base + LENGTH_OFF)
        rel = u32(data, base + DATA_OFF)
        absolute = data_base + rel
        valid = length > 0 and absolute >= 0 and absolute + length <= len(data)
        digest = sha_bytes(data[absolute:absolute + length]) if valid else "INVALID"
        slots.append(dict(slot=slot, width=width, height=height, length=length,
                          rel=rel, absolute=absolute, valid=valid, sha=digest))
    return dict(image_id=image_id, index=index, header_off=header_off,
                image_type=image_type, entry_count=entry_count, slots=slots)


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    rc, out = run(["/usr/bin/sw_vers", "-productVersion"])
    product = out.strip() if rc == 0 else "UNKNOWN"
    rc, out = run(["/usr/bin/sw_vers", "-buildVersion"])
    build = out.strip() if rc == 0 else "UNKNOWN"
    expected = EXPECTED.get(product)
    if expected is None:
        expected = EXPECTED["10.7.5"]
        issues.append("unsupported product version")
    elif build != expected["build"]:
        issues.append("unexpected build version")

    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-frame-relocation.")
    try:
        thin_path = os.path.join(tmpdir, "CoreUI.%s" % expected["arch"])
        coreui_digest = "MISSING"
        body = []
        frame_addr = None
        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
        elif not thin(COREUI, expected["arch"], thin_path):
            issues.append("CoreUI required architecture unavailable")
        else:
            coreui_digest = sha_file(thin_path)
            if coreui_digest != expected["coreui_sha"]:
                issues.append("CoreUI slice SHA mismatch")
            rc1, nm = run(["/usr/bin/nm", "-nm", thin_path])
            rc2, dis = run(["/usr/bin/otool", "-tvV", thin_path])
            if rc1 != 0 or rc2 != 0:
                issues.append("CoreUI static tools failed")
            else:
                symbols, by_name = parse_symbols(nm)
                rows = parse_rows(dis)
                frame_addr, body = symbol_body(symbols, rows, DRAW_FRAME)
                if frame_addr is None:
                    issues.append("DrawWindowFrameDark missing")

        sart_digest = "MISSING"
        sart_data = b""
        version = 0
        count = 0
        data_base = 0
        if not os.path.isfile(SARTFILE):
            issues.append("SArtFile missing")
        else:
            size = os.path.getsize(SARTFILE)
            sart_digest = sha_file(SARTFILE)
            sart_data = open(SARTFILE, "rb").read()
            if size != expected["sart_size"]:
                issues.append("SArtFile size mismatch")
            if sart_digest != expected["sart_sha"]:
                issues.append("SArtFile SHA mismatch")
            if len(sart_data) < 8:
                issues.append("SArtFile header too short")
            else:
                version = u16(sart_data, 0)
                count = u16(sart_data, 2)
                data_base = u32(sart_data, 4)
                if version != 2:
                    issues.append("SArtFile version mismatch")
                if count != expected["count"]:
                    issues.append("SArtFile count mismatch")

        hits = target_hits(body, expected["target_ids"], expected["expected_callee"])
        observed_order = [x["image_id"] for x in hits]
        if observed_order != expected["target_ids"]:
            issues.append("frame target constant order mismatch")
        if len(hits) != len(expected["target_ids"]):
            issues.append("frame target constant count mismatch")
        for item in hits:
            if not item["callee_ok"]:
                issues.append("frame target not followed by expected image constructor: 0x%04x" % item["image_id"])

        records = []
        for image_id in expected["target_ids"]:
            rec = read_record(sart_data, count, image_id, data_base) if sart_data else None
            if rec is None:
                issues.append("target SArtFile record missing: 0x%04x" % image_id)
                continue
            records.append(rec)
            if (rec["image_type"], rec["entry_count"]) != expected["expected_type_count"]:
                issues.append("target record type/count mismatch: 0x%04x" % image_id)
            if not rec["slots"]:
                issues.append("target record has no slots: 0x%04x" % image_id)
                continue
            slot0 = rec["slots"][0]
            if (slot0["width"], slot0["height"], slot0["length"]) != (11, 11, 484):
                issues.append("target slot0 not 11x11/484: 0x%04x" % image_id)
            if not slot0["valid"]:
                issues.append("target slot0 provider invalid: 0x%04x" % image_id)
            if product == "10.7.5" and image_id in ANCHOR_HASHES:
                if slot0["sha"] != ANCHOR_HASHES[image_id]:
                    issues.append("exact relocation anchor hash mismatch: 0x%04x" % image_id)

        fp = open(output, "w")
        try:
            line(fp, "== PPC Carbon GUI CoreUI window-frame frame-ID relocation audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % expected["arch"])
            line(fp, "coreui_slice_sha256=%s" % coreui_digest)
            line(fp, "expected_coreui_slice_sha256=%s" % expected["coreui_sha"])
            line(fp, "coreui_slice_exact=%s" %
                 ("YES" if coreui_digest == expected["coreui_sha"] else "NO"))
            line(fp, "sartfile_sha256=%s" % sart_digest)
            line(fp, "expected_sartfile_sha256=%s" % expected["sart_sha"])
            line(fp, "sartfile_exact=%s" %
                 ("YES" if sart_digest == expected["sart_sha"] else "NO"))
            line(fp, "sartfile_version=%d" % version)
            line(fp, "sartfile_entry_count=%d" % count)
            line(fp, "sartfile_data_region_base=0x%x" % data_base)
            line(fp, "draw_window_frame_dark_address=%s" %
                 ("0x%x" % frame_addr if frame_addr is not None else "MISSING"))

            line(fp)
            line(fp, "== Renderer target order ==")
            line(fp, "expected_target_order=%s" %
                 ",".join("0x%04x" % x for x in expected["target_ids"]))
            line(fp, "observed_target_order=%s" %
                 ",".join("0x%04x" % x for x in observed_order))
            line(fp, "expected_image_constructor_fragment=%s" % expected["expected_callee"])
            for item in hits:
                line(fp, "target image_id=0x%04x constant_address=0x%x call_address=%s callee_match=%s" %
                     (item["image_id"], item["const_addr"],
                      "0x%x" % item["call_addr"] if item["call_addr"] is not None else "MISSING",
                      "YES" if item["callee_ok"] else "NO"))
                line(fp, "constant_raw=%s" % item["const_raw"])
                line(fp, "call_raw=%s" % (item["call_raw"] or "MISSING"))

            line(fp)
            line(fp, "== Target SArtFile records ==")
            for rec in records:
                line(fp, "record image_id=0x%04x index=%d type=%d count=%d header_offset=0x%x" %
                     (rec["image_id"], rec["index"], rec["image_type"],
                      rec["entry_count"], rec["header_off"]))
                for slot in rec["slots"]:
                    line(fp, "slot image_id=0x%04x slot=%d width=%d height=%d provider_length=%d provider_data_offset=0x%x provider_absolute_offset=0x%x provider_range_valid=%s provider_sha256=%s" %
                         (rec["image_id"], slot["slot"], slot["width"],
                          slot["height"], slot["length"], slot["rel"],
                          slot["absolute"], "YES" if slot["valid"] else "NO",
                          slot["sha"]))

            line(fp)
            line(fp, "== Cross-release mapping contract ==")
            for legacy_id, lion_id in LEGACY_TO_LION:
                line(fp, "mapping legacy_id=0x%04x lion_id=0x%04x delta=-0x18" %
                     (legacy_id, lion_id))
            line(fp, "mapping_order_snow=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91")
            line(fp, "mapping_order_lion=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79")
            line(fp, "exact_byte_anchor_count=3")
            line(fp, "id_only_remap_warning=Lion_targets_are_type1_count2;_old_PPC_type1_scale_path_may_select_slot1")

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "frame_id_relocation_contract_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility artifact was built or loaded.")
            line(fp, "CoreUI and SArtFile.bin were opened read-only.")
            line(fp, "Only a temporary CoreUI architecture slice was created and removed.")
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
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
