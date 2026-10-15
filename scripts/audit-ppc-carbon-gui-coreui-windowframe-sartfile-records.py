#!/usr/bin/python
from __future__ import print_function

import binascii
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "2"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-sartfile-records-v2"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
SARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        coreui_sha="5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        sart_size=811436,
        sart_sha="62eb745beaafa0a24111c0ac3b3452cebfda4aeec5e56e51b054ae2d62f778b2",
        sart_version=2,
        sart_count=237,
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        coreui_sha="5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        sart_size=9370228,
        sart_sha="29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b",
        sart_version=2,
        sart_count=348,
    ),
}

FRAME_IDS = [
    (1, 0x4e8e),
    (2, 0x4e90),
    (3, 0x4e89),
    (4, 0x4e8a),
    (5, 0x4e8d),
    (6, 0x4e8f),
    (7, 0x4e91),
]

SHARED_IMAGE_ID_BASE = 0x4e20
OFFSET_TABLE_BASE = 0x08
OFFSET_TABLE_STRIDE = 4
CONSTRUCTOR_SLOT_STRIDE = 0x0c
CONSTRUCTOR_WIDTH_OFFSET = 0x0c
CONSTRUCTOR_HEIGHT_OFFSET = 0x0e
CONSTRUCTOR_LENGTH_OFFSET = 0x10
CONSTRUCTOR_DATA_OFFSET = 0x14

SNOW_READER_METHODS = [
    "__ZN18CUISharedArtReader5SetupEv",
    "__ZN18CUISharedArtReader14GetImageHeaderEl",
    "__ZN18CUISharedArtReader12GetImageTypeEl",
    "__ZN18CUISharedArtReader13GetEntryCountEl",
    "__ZN18CUISharedArtReader11CreateImageElf",
]

FOCUS_RE = re.compile(
    r"CUISharedArtReader|SArtFile|ArtFile|CFURL|CFBundle|CFData|"
    r"mmap|open|read|fopen|malloc|free|CGImage"
)


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
            b = fp.read(1024 * 1024)
            if not b:
                break
            h.update(b)
    finally:
        fp.close()
    return h.hexdigest()


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def bval(ch):
    if isinstance(ch, int):
        return ch
    return ord(ch)


def hexbytes(data):
    value = binascii.hexlify(data)
    if not isinstance(value, str):
        value = value.decode("ascii")
    return value


def u16le(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32le(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


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


def parse_disassembly(text):
    out = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex(parts[0])
        if addr is not None:
            out.append((addr, raw))
    return out


def body_for_name(rows, symbols, by_name, name):
    if name not in by_name:
        return None, []
    addr = by_name[name]
    for i, item in enumerate(symbols):
        if item[0] == addr and item[1] == name:
            end = symbols[i + 1][0] if i + 1 < len(symbols) else None
            body = [(a, raw) for a, raw in rows
                    if a >= addr and (end is None or a < end)]
            return addr, body
    return addr, []


def emit_body(fp, name, addr, body):
    line(fp)
    line(fp, "== CoreUI reader method: %s ==" % name)
    line(fp, "present=%s" % ("YES" if addr is not None else "NO"))
    if addr is None:
        return
    line(fp, "symbol_address=0x%08x" % addr)
    line(fp, "instruction_lines=%d" % len(body))
    line(fp, "-- focused lines --")
    focused = [raw for a, raw in body if FOCUS_RE.search(raw)]
    if focused:
        for raw in focused:
            line(fp, raw)
    else:
        line(fp, "NONE")
    line(fp, "-- full body --")
    for a, raw in body:
        line(fp, raw)


def safe_slot(data, header_off, slot):
    base = header_off + slot * CONSTRUCTOR_SLOT_STRIDE
    need = base + CONSTRUCTOR_DATA_OFFSET + 4
    if base < 0 or need > len(data):
        return None
    return dict(
        width=u16le(data, base + CONSTRUCTOR_WIDTH_OFFSET),
        height=u16le(data, base + CONSTRUCTOR_HEIGHT_OFFSET),
        length=u32le(data, base + CONSTRUCTOR_LENGTH_OFFSET),
        data_offset=u32le(data, base + CONSTRUCTOR_DATA_OFFSET),
    )


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-sart-records.")

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

        local = os.path.join(tmpdir, "CoreUI.%s" % expected["arch"])
        coreui_digest = "MISSING"
        symbols = []
        by_name = {}
        rows = []

        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
        elif not thin(COREUI, expected["arch"], local):
            issues.append("required CoreUI slice unavailable")
        else:
            coreui_digest = sha256(local)
            if coreui_digest != expected["coreui_sha"]:
                issues.append("CoreUI slice SHA mismatch")
            rc_nm, nm = run(["/usr/bin/nm", "-nm", local])
            rc_dis, dis = run(["/usr/bin/otool", "-tvV", local])
            if rc_nm != 0:
                issues.append("nm failed")
            else:
                symbols, by_name = parse_symbols(nm)
            if rc_dis != 0:
                issues.append("otool disassembly failed")
            else:
                rows = parse_disassembly(dis)

        sart_data = ""
        sart_digest = "MISSING"
        sart_size = 0
        sart_version = None
        sart_count = None

        if not os.path.isfile(SARTFILE):
            issues.append("SArtFile.bin missing")
        else:
            sart_size = os.path.getsize(SARTFILE)
            sart_digest = sha256(SARTFILE)
            fp_in = open(SARTFILE, "rb")
            try:
                sart_data = fp_in.read()
            finally:
                fp_in.close()
            if sart_size != expected["sart_size"]:
                issues.append("SArtFile size mismatch")
            if sart_digest != expected["sart_sha"]:
                issues.append("SArtFile SHA mismatch")
            if len(sart_data) < 8:
                issues.append("SArtFile header too short")
            else:
                sart_version = u16le(sart_data, 0)
                sart_count = u16le(sart_data, 2)
                if sart_version != expected["sart_version"]:
                    issues.append("SArtFile version mismatch")
                if sart_count != expected["sart_count"]:
                    issues.append("SArtFile count mismatch")
                if OFFSET_TABLE_BASE + sart_count * OFFSET_TABLE_STRIDE > len(sart_data):
                    issues.append("SArtFile offset table outside file")

        setup_table_base_verified = None
        if product == "10.6.8":
            setup_addr, setup_body = body_for_name(
                rows, symbols, by_name, "__ZN18CUISharedArtReader5SetupEv")
            setup_has_base = any("addi\tr7,r11,0x8" in raw
                                 for a, raw in setup_body)
            setup_stores_base = any("stw\tr7,0x34f8" in raw
                                    for a, raw in setup_body)
            setup_table_base_verified = (
                setup_addr is not None and setup_has_base and setup_stores_base)
            if not setup_table_base_verified:
                issues.append("Snow Setup does not prove SArtFile offset table base +0x08")

        fp = open(report, "w")
        try:
            line(fp, "== PPC Carbon GUI CoreUI window-frame SArtFile record audit ==")
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
                 ("YES" if sart_digest == expected["sart_sha"] and
                  sart_size == expected["sart_size"] else "NO"))
            line(fp, "sartfile_size=%d" % sart_size)
            line(fp, "sartfile_version=%s" %
                 (str(sart_version) if sart_version is not None else "MISSING"))
            line(fp, "sartfile_entry_count=%s" %
                 (str(sart_count) if sart_count is not None else "MISSING"))
            if product == "10.7.5":
                line(fp, "runtime_ppc_coreui_contract=accepted_snow_ppc_cache")
                line(fp, "native_lion_coreui_role=release_reference_only")
            else:
                line(fp, "runtime_ppc_coreui_contract=local_snow_ppc_reference")

            line(fp)
            line(fp, "== Reviewed shared-reader contract ==")
            line(fp, "shared_image_id_base=0x%04x" % SHARED_IMAGE_ID_BASE)
            line(fp, "image_id_to_index_formula=image_id-0x%04x" % SHARED_IMAGE_ID_BASE)
            line(fp, "sartfile_offset_table_base=0x%02x" % OFFSET_TABLE_BASE)
            line(fp, "sartfile_offset_table_base_source=Snow_Setup_mapped_base_plus_0x08")
            if product == "10.6.8":
                line(fp, "snow_setup_offset_table_base_verified=%s" %
                     ("YES" if setup_table_base_verified else "NO"))
            else:
                line(fp, "snow_setup_offset_table_base_verified=accepted_snow_ppc_contract")
            line(fp, "sartfile_offset_table_stride=%d" % OFFSET_TABLE_STRIDE)
            line(fp, "constructor_slot_stride=0x%02x" % CONSTRUCTOR_SLOT_STRIDE)
            line(fp, "constructor_width_offset=slot_base+0x%02x" % CONSTRUCTOR_WIDTH_OFFSET)
            line(fp, "constructor_height_offset=slot_base+0x%02x" % CONSTRUCTOR_HEIGHT_OFFSET)
            line(fp, "constructor_provider_length_offset=slot_base+0x%02x" % CONSTRUCTOR_LENGTH_OFFSET)
            line(fp, "constructor_provider_data_offset=slot_base+0x%02x" % CONSTRUCTOR_DATA_OFFSET)
            line(fp, "target_frame_image_count=%d" % len(FRAME_IDS))

            if product == "10.6.8":
                for name in SNOW_READER_METHODS:
                    addr, body = body_for_name(rows, symbols, by_name, name)
                    emit_body(fp, name, addr, body)
                    if addr is None:
                        issues.append("Snow reader method missing: %s" % name)

            line(fp)
            line(fp, "== Target SArtFile frame-image records ==")
            if sart_count is not None and len(sart_data) >= 8:
                for call_order, image_id in FRAME_IDS:
                    index = image_id - SHARED_IMAGE_ID_BASE
                    table_off = OFFSET_TABLE_BASE + index * OFFSET_TABLE_STRIDE
                    line(fp)
                    line(fp, "frame_image_call_order=%d image_id=0x%04x index=%d table_offset=0x%x" %
                         (call_order, image_id, index, table_off))
                    if index <= 0 or index >= sart_count:
                        line(fp, "record_valid=NO reason=index_out_of_range")
                        issues.append("frame image index out of range: 0x%04x" % image_id)
                        continue
                    if table_off + 4 > len(sart_data):
                        line(fp, "record_valid=NO reason=table_out_of_range")
                        issues.append("frame image table offset out of range: 0x%04x" % image_id)
                        continue
                    header_off = u32le(sart_data, table_off)
                    line(fp, "header_offset=0x%x" % header_off)
                    if header_off <= 0 or header_off + 0x30 > len(sart_data):
                        line(fp, "record_valid=NO reason=header_out_of_range")
                        issues.append("frame image header offset out of range: 0x%04x" % image_id)
                        continue
                    line(fp, "record_valid=YES")
                    line(fp, "header_prefix_48_hex=%s" %
                         hexbytes(sart_data[header_off:header_off + 0x30]))
                    if index + 1 < sart_count:
                        next_off = u32le(
                            sart_data,
                            OFFSET_TABLE_BASE + (index + 1) * OFFSET_TABLE_STRIDE)
                        line(fp, "next_index_header_offset=0x%x" % next_off)
                        if next_off > header_off:
                            line(fp, "next_index_header_delta=0x%x" %
                                 (next_off - header_off))
                        else:
                            line(fp, "next_index_header_delta=NONMONOTONIC")

                    for slot in (0, 1):
                        slot_data = safe_slot(sart_data, header_off, slot)
                        if slot_data is None:
                            line(fp, "slot=%d valid=NO" % slot)
                            continue
                        line(fp,
                             "slot=%d valid=YES width=%d height=%d provider_length=%d provider_data_offset=0x%x" %
                             (slot, slot_data["width"], slot_data["height"],
                              slot_data["length"], slot_data["data_offset"]))

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for item in issues:
                    line(fp, "validation_issue=%s" % item)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "sartfile_frame_record_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility artifact was built or loaded.")
            line(fp, "No CoreUI resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
            line(fp, "Only a temporary CoreUI architecture slice was created and removed.")
            line(fp, "SArtFile.bin was opened read-only.")
        finally:
            fp.close()

        print("Created: %s" % report)
        if issues:
            print("RESULT: FAIL")
            for item in issues:
                print("validation_issue=%s" % item)
            return 1
        print("RESULT: PASS")
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
