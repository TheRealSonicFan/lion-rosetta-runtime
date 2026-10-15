#!/usr/bin/python
from __future__ import print_function

import binascii
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-shared-art-source-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
COREUI_RESOURCES = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        slice_sha="5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        slice_sha="5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
    ),
}

CREATE_FROM_BYTES = "__ZN18CUISharedArtReader20CreateImageFromBytesEll"
GET_IMAGE_HEADER = "__ZN18CUISharedArtReader14GetImageHeaderEl"

RESOURCE_NAMES = [
    "ArtFile.bin",
    "ArtFile200.bin",
    "SArtFile.bin",
]

FOCUS_RE = re.compile(
    r"CUISharedArtReader|CreateImageFromBytes|GetImageHeader|"
    r"ArtFile|SArtFile|CGImage|CGDataProvider|CFData|"
    r"mmap|open|read|malloc|memcpy|free"
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


def prefix_hex(path, count=128):
    fp = open(path, "rb")
    try:
        data = fp.read(count)
    finally:
        fp.close()
    value = binascii.hexlify(data)
    if not isinstance(value, str):
        value = value.decode("ascii")
    return value


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


def find_containing(symbols, addr):
    best = None
    for i, item in enumerate(symbols):
        start, name = item
        if start > addr:
            break
        end = symbols[i + 1][0] if i + 1 < len(symbols) else None
        if end is None or addr < end:
            best = (i, start, end, name)
    return best


def symbol_body(rows, symbols, index):
    start = symbols[index][0]
    end = symbols[index + 1][0] if index + 1 < len(symbols) else None
    return [(addr, raw) for addr, raw in rows
            if addr >= start and (end is None or addr < end)]


def body_for_name(rows, symbols, by_name, name):
    if name not in by_name:
        return None, []
    addr = by_name[name]
    for i, item in enumerate(symbols):
        if item[0] == addr and item[1] == name:
            return addr, symbol_body(rows, symbols, i)
    return addr, []


def reverse_refs(rows, symbol_name, symbol_addr):
    out = []
    addr_hexes = [
        "0x%x" % symbol_addr,
        "0x%08x" % symbol_addr,
    ]
    for addr, raw in rows:
        if addr == symbol_addr:
            continue
        if symbol_name in raw or any(token in raw for token in addr_hexes):
            out.append((addr, raw))
    return out


def context_for_addr(rows, addr, radius=16):
    idx = None
    for i, item in enumerate(rows):
        if item[0] == addr:
            idx = i
            break
    if idx is None:
        return []
    lo = max(0, idx - radius)
    hi = min(len(rows), idx + radius + 1)
    return rows[lo:hi]


def emit_body(fp, title, addr, body):
    line(fp)
    line(fp, "== %s ==" % title)
    line(fp, "symbol_address=%s" % ("0x%08x" % addr if addr is not None else "MISSING"))
    line(fp, "instruction_lines=%d" % len(body))
    line(fp, "-- focused source/image lines --")
    focused = [raw for item_addr, raw in body if FOCUS_RE.search(raw)]
    if focused:
        for raw in focused:
            line(fp, raw)
    else:
        line(fp, "NONE")
    line(fp, "-- full body --")
    if body:
        for item_addr, raw in body:
            line(fp, raw)
    else:
        line(fp, "NONE")


def emit_resource(fp, path, name):
    line(fp, "resource_name=%s" % name)
    line(fp, "resource_path=%s" % path)
    if not os.path.isfile(path):
        line(fp, "resource_present=NO")
        return False
    line(fp, "resource_present=YES")
    line(fp, "resource_size=%d" % os.path.getsize(path))
    line(fp, "resource_sha256=%s" % sha256(path))
    line(fp, "resource_prefix_128_hex=%s" % prefix_hex(path, 128))
    return True


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-shared-art-source.")

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
        digest = "MISSING"
        symbols = []
        by_name = {}
        rows = []
        strings_text = ""

        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
        elif not thin(COREUI, expected["arch"], local):
            issues.append("required CoreUI slice unavailable")
        else:
            digest = sha256(local)
            if digest != expected["slice_sha"]:
                issues.append("CoreUI slice SHA mismatch")

            rc_nm, nm = run(["/usr/bin/nm", "-nm", local])
            rc_dis, dis = run(["/usr/bin/otool", "-tvV", local])
            rc_strings, strings_text = run(["/usr/bin/strings", local])

            if rc_nm != 0:
                issues.append("nm failed")
            else:
                symbols, by_name = parse_symbols(nm)
            if rc_dis != 0:
                issues.append("otool disassembly failed")
            else:
                rows = parse_disassembly(dis)
            if rc_strings != 0:
                issues.append("strings failed")

        fp = open(report, "w")
        try:
            line(fp, "== PPC Carbon GUI CoreUI shared-art source audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % expected["arch"])
            line(fp, "coreui_slice_sha256=%s" % digest)
            line(fp, "expected_coreui_slice_sha256=%s" % expected["slice_sha"])
            line(fp, "coreui_slice_exact=%s" %
                 ("YES" if digest == expected["slice_sha"] else "NO"))
            if product == "10.7.5":
                line(fp, "runtime_ppc_coreui_contract=accepted_snow_ppc_cache")
                line(fp, "native_lion_coreui_role=release_reference_only")
            else:
                line(fp, "runtime_ppc_coreui_contract=local_snow_ppc_reference")

            line(fp)
            line(fp, "== Reviewed caller-resolution boundary ==")
            line(fp, "divergent_return_offset=0x0002ad34")
            line(fp, "divergent_symbol=%s" % CREATE_FROM_BYTES)
            line(fp, "snow_geometry=5x11x11x8/32/bpr44")
            line(fp, "lion_geometry=256x256x8/32/bpr1024|2x62x8/32/bpr8")
            line(fp, "constructor_results_nonnull=YES")
            line(fp, "header_width_field_offset=0x0c")
            line(fp, "header_height_field_offset=0x0e")
            line(fp, "header_provider_length_field_offset=0x10")
            line(fp, "header_provider_data_offset_field_offset=0x14")
            line(fp, "header_fields_byte_swapped_before_use=YES")
            line(fp, "next_boundary=shared_art_reader_header_source")

            reader_symbols = [(addr, name) for addr, name in symbols
                              if "CUISharedArtReader" in name]
            line(fp)
            line(fp, "== CUISharedArtReader symbol inventory ==")
            line(fp, "reader_symbol_count=%d" % len(reader_symbols))
            if reader_symbols:
                for addr, name in reader_symbols:
                    line(fp, "reader_symbol=0x%08x %s" % (addr, name))
            else:
                line(fp, "reader_symbol=NONE")

            create_addr, create_body = body_for_name(
                rows, symbols, by_name, CREATE_FROM_BYTES)
            header_addr, header_body = body_for_name(
                rows, symbols, by_name, GET_IMAGE_HEADER)

            line(fp)
            line(fp, "== CreateImageFromBytes linkage ==")
            line(fp, "create_from_bytes_present=%s" %
                 ("YES" if create_addr is not None else "NO"))
            if create_addr is not None:
                refs = reverse_refs(rows, CREATE_FROM_BYTES, create_addr)
                line(fp, "create_from_bytes_address=0x%08x" % create_addr)
                line(fp, "create_from_bytes_direct_reference_count=%d" % len(refs))
                for ref_addr, raw in refs:
                    found = find_containing(symbols, ref_addr)
                    if found is None:
                        line(fp, "reference=0x%08x containing_symbol=UNRESOLVED raw=%s" %
                             (ref_addr, raw))
                        continue
                    index, start, end, name = found
                    line(fp, "reference=0x%08x containing_symbol=%s containing_start=0x%08x raw=%s" %
                         (ref_addr, name, start, raw))
                    line(fp, "-- reference context 0x%08x --" % ref_addr)
                    for item_addr, item_raw in context_for_addr(rows, ref_addr):
                        line(fp, item_raw)
                    emit_body(fp, "direct caller of CreateImageFromBytes: %s" % name,
                              start, symbol_body(rows, symbols, index))
            elif product == "10.6.8":
                issues.append("Snow CreateImageFromBytes symbol missing")

            line(fp)
            line(fp, "== GetImageHeader linkage ==")
            line(fp, "get_image_header_present=%s" %
                 ("YES" if header_addr is not None else "NO"))
            if header_addr is not None:
                refs = reverse_refs(rows, GET_IMAGE_HEADER, header_addr)
                line(fp, "get_image_header_address=0x%08x" % header_addr)
                line(fp, "get_image_header_direct_reference_count=%d" % len(refs))
                for ref_addr, raw in refs:
                    found = find_containing(symbols, ref_addr)
                    if found is None:
                        line(fp, "reference=0x%08x containing_symbol=UNRESOLVED raw=%s" %
                             (ref_addr, raw))
                    else:
                        index, start, end, name = found
                        line(fp, "reference=0x%08x containing_symbol=%s containing_start=0x%08x raw=%s" %
                             (ref_addr, name, start, raw))
                emit_body(fp, "GetImageHeader body", header_addr, header_body)
            elif product == "10.6.8":
                issues.append("Snow GetImageHeader symbol missing")

            if create_addr is not None:
                emit_body(fp, "CreateImageFromBytes body", create_addr, create_body)

            line(fp)
            line(fp, "== CoreUI resource-name strings ==")
            resource_string_lines = []
            for raw in strings_text.splitlines():
                if ("ArtFile" in raw or "SArtFile" in raw or
                        "SharedArt" in raw or ".bin" in raw):
                    resource_string_lines.append(raw)
            line(fp, "resource_string_count=%d" % len(resource_string_lines))
            if resource_string_lines:
                for raw in resource_string_lines:
                    line(fp, raw)
            else:
                line(fp, "NONE")

            line(fp)
            line(fp, "== CoreUI resource identities ==")
            present = {}
            for name in RESOURCE_NAMES:
                path = os.path.join(COREUI_RESOURCES, name)
                present[name] = emit_resource(fp, path, name)
                line(fp)
            if not present.get("ArtFile.bin", False):
                issues.append("ArtFile.bin missing")
            if not present.get("SArtFile.bin", False):
                issues.append("SArtFile.bin missing")

            line(fp, "== Audit validation ==")
            if issues:
                for item in issues:
                    line(fp, "validation_issue=%s" % item)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "shared_art_source_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility artifact was built or loaded.")
            line(fp, "No CoreUI resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
            line(fp, "Only a temporary CoreUI architecture slice was created and removed.")
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
