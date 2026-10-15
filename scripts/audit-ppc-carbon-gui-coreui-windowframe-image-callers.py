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
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-image-caller-resolution-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"

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

LIVE_SITES = [
    (0x0002ad34, "divergent-nonbutton-image", 5, 2,
     "Snow=5x11x11x8/32/bpr44;Lion=256x256+bpr1024|2x62+bpr8"),
    (0x0001bdb0, "gray-gradient-control", 2, 2,
     "Snow=Lion=2x1x22x8/8/bpr1"),
    (0x000299e0, "exact-six-titlebar-artfile-control", 6, 6,
     "Snow=14x16/bpr56;Lion=16x16/bpr64;accepted-bitmapinfo-adapter"),
]

FOCUS_RE = re.compile(
    r"CGImageCreate|CGDataProvider|CGColorSpace|CGBitmap|CFData|"
    r"CUIElement|ArtFile|CreateImage|Load|memcpy|malloc|free"
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


def find_row(rows, addr):
    for row_addr, raw in rows:
        if row_addr == addr:
            return raw
    return None


def context_for_addr(body, addr, radius=16):
    idx = None
    for i, item in enumerate(body):
        if item[0] == addr:
            idx = i
            break
    if idx is None:
        return []
    lo = max(0, idx - radius)
    hi = min(len(body), idx + radius + 1)
    return body[lo:hi]


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


def parse_snow_report(path):
    mapping = {}
    current = None
    fp = open(path, "r")
    try:
        for raw in fp:
            s = raw.strip()
            if s.startswith("live_return_offset="):
                fields = {}
                for part in s.split():
                    if "=" in part:
                        k, v = part.split("=", 1)
                        fields[k] = v
                current = fields.get("live_return_offset")
            elif current is not None and s.startswith("resolved_symbol="):
                mapping[current] = s.split("=", 1)[1]
                current = None
    finally:
        fp.close()
    return mapping


def emit_body(fp, body, target_call_addr=None):
    line(fp, "instruction_lines=%d" % len(body))
    line(fp, "-- focused resource/image lines --")
    focused = [raw for addr, raw in body if FOCUS_RE.search(raw)]
    if focused:
        for raw in focused:
            line(fp, raw)
    else:
        line(fp, "NONE")

    if target_call_addr is not None:
        line(fp, "-- target CGImageCreate call context --")
        ctx = context_for_addr(body, target_call_addr)
        if ctx:
            for addr, raw in ctx:
                line(fp, raw)
        else:
            line(fp, "NONE")

    line(fp, "-- full body --")
    for addr, raw in body:
        line(fp, raw)


def main():
    if len(sys.argv) < 2:
        print("usage: %s OUTPUT [SNOW_REPORT]" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    snow_report = sys.argv[2] if len(sys.argv) > 2 else None
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-coreui-image-callers.")

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
        symbols = []
        by_name = {}
        rows = []
        digest = "MISSING"

        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
        elif not thin(COREUI, expected["arch"], local):
            issues.append("required CoreUI slice unavailable")
        else:
            digest = sha256(local)
            if digest != expected["slice_sha"]:
                issues.append("CoreUI slice SHA mismatch")
            rc1, nm = run(["/usr/bin/nm", "-nm", local])
            rc2, dis = run(["/usr/bin/otool", "-tvV", local])
            if rc1 != 0:
                issues.append("nm failed")
            else:
                symbols, by_name = parse_symbols(nm)
            if rc2 != 0:
                issues.append("otool disassembly failed")
            else:
                rows = parse_disassembly(dis)

        snow_mapping = {}
        if product == "10.7.5":
            if snow_report is None or not os.path.isfile(snow_report):
                issues.append("Lion mode requires Snow report")
            else:
                snow_mapping = parse_snow_report(snow_report)
                if len(snow_mapping) != len(LIVE_SITES):
                    issues.append("Snow report caller mapping incomplete")

        fp = open(report, "w")
        try:
            line(fp, "== PPC Carbon GUI CoreUI window-frame image caller resolution ==")
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
                line(fp, "native_lion_coreui_role=same-symbol release reference")
            else:
                line(fp, "runtime_ppc_coreui_contract=local_snow_ppc_reference")

            line(fp)
            line(fp, "== Reviewed live image-constructor differential ==")
            line(fp, "snow_total_coreui_cgimagecreate_calls=13")
            line(fp, "lion_total_coreui_cgimagecreate_calls=10")
            line(fp, "gray_gradient_stream_equivalent=YES")
            line(fp, "exact_six_titlebar_stream_known_compatible=YES")
            line(fp, "new_divergent_return_offset=0x0002ad34")
            line(fp, "snow_divergent_count=5")
            line(fp, "snow_divergent_geometry=11x11x8/32/bpr44")
            line(fp, "lion_divergent_count=2")
            line(fp, "lion_divergent_geometry=256x256x8/32/bpr1024|2x62x8/32/bpr8")
            line(fp, "divergent_raw_bitmapinfo=0x00000002")
            line(fp, "divergent_results_nonnull=YES")

            if product == "10.6.8":
                for ret_addr, role, snow_count, lion_count, observed in LIVE_SITES:
                    call_addr = ret_addr - 4
                    line(fp)
                    line(fp, "== Live CGImageCreate caller ==")
                    line(fp, "live_return_offset=0x%08x role=%s snow_count=%d lion_count=%d observed=%s" %
                         (ret_addr, role, snow_count, lion_count, observed))
                    line(fp, "expected_call_instruction=0x%08x" % call_addr)

                    found = find_containing(symbols, ret_addr)
                    if found is None:
                        line(fp, "resolved=NO")
                        issues.append("live return offset 0x%08x unresolved" % ret_addr)
                        continue

                    index, start, end, name = found
                    body = symbol_body(rows, symbols, index)
                    call_line = find_row(rows, call_addr)
                    line(fp, "resolved=YES")
                    line(fp, "resolved_symbol=%s" % name)
                    line(fp, "symbol_start=0x%08x" % start)
                    line(fp, "return_delta=0x%x" % (ret_addr - start))
                    line(fp, "symbol_end=%s" %
                         ("0x%08x" % end if end is not None else "UNKNOWN"))
                    line(fp, "target_call_line=%s" %
                         (call_line if call_line is not None else "MISSING"))
                    call_exact = call_line is not None and "CGImageCreate" in call_line
                    line(fp, "target_call_is_CGImageCreate=%s" %
                         ("YES" if call_exact else "NO"))
                    if not call_exact:
                        issues.append("0x%08x target call is not annotated CGImageCreate" % call_addr)

                    refs = reverse_refs(rows, name, start)
                    line(fp, "direct_symbol_reference_count=%d" % len(refs))
                    line(fp, "-- direct symbol references --")
                    if refs:
                        for addr, raw in refs:
                            line(fp, raw)
                    else:
                        line(fp, "NONE")

                    emit_body(fp, body, call_addr)
            else:
                line(fp)
                line(fp, "== Lion native same-symbol reference ==")
                for ret_addr, role, snow_count, lion_count, observed in LIVE_SITES:
                    key = "0x%08x" % ret_addr
                    name = snow_mapping.get(key)
                    line(fp)
                    line(fp, "live_snow_return_offset=%s role=%s snow_count=%d lion_count=%d observed=%s" %
                         (key, role, snow_count, lion_count, observed))
                    line(fp, "snow_resolved_symbol=%s" %
                         (name if name is not None else "MISSING"))
                    if name is None:
                        line(fp, "native_same_symbol_present=NO")
                        continue

                    native_addr, body = body_for_name(rows, symbols, by_name, name)
                    line(fp, "native_same_symbol_present=%s" %
                         ("YES" if native_addr is not None else "NO"))
                    if native_addr is None:
                        continue
                    line(fp, "native_symbol_address=0x%08x" % native_addr)
                    refs = reverse_refs(rows, name, native_addr)
                    line(fp, "direct_symbol_reference_count=%d" % len(refs))
                    line(fp, "-- direct symbol references --")
                    if refs:
                        for addr, raw in refs:
                            line(fp, raw)
                    else:
                        line(fp, "NONE")
                    emit_body(fp, body)

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for item in issues:
                    line(fp, "validation_issue=%s" % item)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "coreui_image_caller_resolution_exact=YES")
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
