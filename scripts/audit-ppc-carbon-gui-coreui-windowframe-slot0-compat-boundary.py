#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-slot0-compat-boundary-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
EXPECTED_PRODUCT = "10.6.8"
EXPECTED_BUILD = "10K549"
EXPECTED_ARCH = "ppc7400"
EXPECTED_SHA = "5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839"

CUI_CREATE = "__Z15_CUICreateImagelPK13CUIDescriptorf"
SHARED_CREATE = "__ZN18CUISharedArtReader11CreateImageElf"
CREATE_FROM_BYTES = "__ZN18CUISharedArtReader20CreateImageFromBytesEll"
CREATE_SOURCE = "__ZN18CUISharedArtReader17CreateImageSourceEl"
CREATE_PROVIDER = "__ZN18CUISharedArtReader19CreateImageProviderEl"
GET_IMAGE_HEADER = "__ZN18CUISharedArtReader14GetImageHeaderEl"
GET_IMAGE_TYPE = "__ZN18CUISharedArtReader12GetImageTypeEl"
GET_ENTRY_COUNT = "__ZN18CUISharedArtReader13GetEntryCountEl"

TARGETS = [
    CUI_CREATE,
    SHARED_CREATE,
    CREATE_FROM_BYTES,
    CREATE_SOURCE,
    CREATE_PROVIDER,
    GET_IMAGE_HEADER,
]

FOCUS_RE = re.compile(
    r"CUISharedArtReader|CreateImageFromBytes|CreateImageSource|CreateImageProvider|"
    r"GetImageHeader|GetImageType|GetEntryCount|CGImage|CGDataProvider|CFData|"
    r"ImageSource|mmap|open|read|memcpy"
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
            block = fp.read(1024 * 1024)
            if not block:
                break
            h.update(block)
    finally:
        fp.close()
    return h.hexdigest()


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
    by_addr = {}
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
        if addr not in by_addr:
            by_addr[addr] = name
    ordered.sort()
    return ordered, by_name, by_addr


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


def body_for(symbols, rows, name):
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


def call_target(raw):
    if "\tbl\t" not in raw and "\tcalll\t" not in raw:
        return None
    tail = raw.split("\t")[-1].strip()
    token = tail.split()[0] if tail else ""
    return parse_hex(token)


def call_inventory(body, by_addr):
    out = []
    for addr, raw in body:
        if "\tbl\t" not in raw and "\tcalll\t" not in raw:
            continue
        target = call_target(raw)
        resolved = by_addr.get(target) if target is not None else None
        out.append((addr, raw, target, resolved))
    return out


def reverse_refs(rows, name, addr):
    tokens = ["0x%x" % addr, "0x%08x" % addr]
    out = []
    for row_addr, raw in rows:
        if row_addr == addr:
            continue
        if name in raw or any(token in raw for token in tokens):
            out.append((row_addr, raw))
    return out


def containing_symbol(symbols, addr):
    for i, (start, name) in enumerate(symbols):
        end = symbols[i + 1][0] if i + 1 < len(symbols) else None
        if addr >= start and (end is None or addr < end):
            return start, name
    return None, None


def emit_body(fp, title, addr, body, by_addr):
    line(fp)
    line(fp, "== %s ==" % title)
    line(fp, "symbol_address=%s" % ("0x%08x" % addr if addr is not None else "MISSING"))
    line(fp, "instruction_lines=%d" % len(body))
    calls = call_inventory(body, by_addr)
    line(fp, "call_count=%d" % len(calls))
    for call_addr, raw, target, resolved in calls:
        line(fp, "call=0x%08x target=%s resolved=%s raw=%s" %
             (call_addr,
              "0x%08x" % target if target is not None else "INLINE_OR_STUB",
              resolved or "UNRESOLVED",
              raw))
    line(fp, "-- focused lines --")
    focused = [raw for row_addr, raw in body if FOCUS_RE.search(raw)]
    if focused:
        for raw in focused:
            line(fp, raw)
    else:
        line(fp, "NONE")
    line(fp, "-- full body --")
    if body:
        for row_addr, raw in body:
            line(fp, raw)
    else:
        line(fp, "NONE")


def body_contains(body, text):
    return any(text in raw for addr, raw in body)


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-slot0-boundary.")

    try:
        rc, out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = out.strip() if rc == 0 else "UNKNOWN"
        rc, out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = out.strip() if rc == 0 else "UNKNOWN"

        if product != EXPECTED_PRODUCT:
            issues.append("unexpected product version")
        if build != EXPECTED_BUILD:
            issues.append("unexpected build version")

        thin_path = os.path.join(tmpdir, "CoreUI.ppc7400")
        digest = "MISSING"
        symbols = []
        by_name = {}
        by_addr = {}
        rows = []

        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
        elif not thin(COREUI, EXPECTED_ARCH, thin_path):
            issues.append("PPC7400 CoreUI slice unavailable")
        else:
            digest = sha256(thin_path)
            if digest != EXPECTED_SHA:
                issues.append("CoreUI slice SHA mismatch")
            rc1, nm = run(["/usr/bin/nm", "-nm", thin_path])
            rc2, dis = run(["/usr/bin/otool", "-tvV", thin_path])
            if rc1 != 0:
                issues.append("nm failed")
            else:
                symbols, by_name, by_addr = parse_symbols(nm)
            if rc2 != 0:
                issues.append("otool disassembly failed")
            else:
                rows = parse_rows(dis)

        bodies = {}
        for name in TARGETS:
            addr, body = body_for(symbols, rows, name)
            bodies[name] = (addr, body)
            if addr is None:
                issues.append("required symbol missing: %s" % name)

        shared_addr, shared_body = bodies.get(SHARED_CREATE, (None, []))
        if shared_body:
            required_fragments = [
                GET_IMAGE_TYPE,
                GET_ENTRY_COUNT,
                CREATE_FROM_BYTES,
                CREATE_SOURCE,
                "cmpwi\tcr7,r3,0x1",
                "li\tr4,0x1",
            ]
            for frag in required_fragments:
                if not body_contains(shared_body, frag):
                    issues.append("shared CreateImage selection fragment missing: %s" % frag)

        refs = []
        if shared_addr is not None:
            for ref_addr, raw in reverse_refs(rows, SHARED_CREATE, shared_addr):
                start, name = containing_symbol(symbols, ref_addr)
                refs.append((ref_addr, raw, start, name))

        fp = open(report, "w")
        try:
            line(fp, "== PPC Carbon GUI CoreUI window-frame slot-0 compatibility boundary audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % EXPECTED_ARCH)
            line(fp, "coreui_slice_sha256=%s" % digest)
            line(fp, "expected_coreui_slice_sha256=%s" % EXPECTED_SHA)
            line(fp, "coreui_slice_exact=%s" % ("YES" if digest == EXPECTED_SHA else "NO"))
            line(fp, "runtime_on_lion_contract=accepted_exact_snow_ppc_coreui_cache")

            line(fp)
            line(fp, "== Proven relocation input ==")
            line(fp, "legacy_mapping=0x4e8d->0x4e75,0x4e8e->0x4e76,0x4e8f->0x4e77,0x4e90->0x4e78,0x4e91->0x4e79")
            line(fp, "snow_active_slot_contract=type2,count1,slot0,11x11,484")
            line(fp, "lion_mapped_record_contract=type1,count2,slot0=11x11x484,slot1=22x22x1936")
            line(fp, "id_only_remap_safe=NO")
            line(fp, "reason=Snow_PPC_type1_count2_high_scale_path_selects_slot1")

            line(fp)
            line(fp, "== Shared CreateImage direct references ==")
            line(fp, "shared_create_address=%s" %
                 ("0x%08x" % shared_addr if shared_addr is not None else "MISSING"))
            line(fp, "shared_create_direct_reference_count=%d" % len(refs))
            for ref_addr, raw, start, name in refs:
                line(fp, "reference=0x%08x containing_symbol=%s containing_start=%s raw=%s" %
                     (ref_addr, name or "UNRESOLVED",
                      "0x%08x" % start if start is not None else "UNRESOLVED",
                      raw))

            for name in TARGETS:
                addr, body = bodies.get(name, (None, []))
                emit_body(fp, name, addr, body, by_addr)

            line(fp)
            line(fp, "== Static selection semantics ==")
            line(fp, "type2_path=CreateImageFromBytes(image_id,slot0)")
            line(fp, "type1_path=scale_threshold_then_entry_count;_slot0_or_slot1_raw")
            line(fp, "type3_path=scale_equality_then_slot1_raw_else_ImageIO")
            line(fp, "lion_live_old_ids_observed=raw_slot1_for_0x4e8e_and_0x4e8d;_ImageIO_for_remaining_three_active_ids")
            line(fp, "design_requirement=exact_five_ID_relocation_plus_preserve_11x11_slot0_semantics")
            line(fp, "private_method_patch_authorized=NO")
            line(fp, "resource_rewrite_authorized=NO")

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "slot0_compat_boundary_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility artifact was built or loaded.")
            line(fp, "Only a temporary exact PPC CoreUI slice was created and removed.")
            line(fp, "No CoreUI resource, Rosetta cache, WindowServer, CGS, or XNU state was modified.")
        finally:
            fp.close()

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
