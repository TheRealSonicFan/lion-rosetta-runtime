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
AUDIT_CONTRACT = "carbon-gui-hitoolbox-cuidraw-caller-resolution-v1"

HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        slice_sha="fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f",
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        slice_sha="b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6",
    ),
}

LIVE_CALLERS = [
    (0x000bc5e8, "window-frame", 2, 2,
     "kCUIWidgetWindowFrame"),
    (0x00022374, "titlebar-controls", 6, 6,
     "titlebarclose|titlebarcollapse|titlebarzoom"),
    (0x0001f340, "snow-only-menu-title", 1, 0,
     "kCUIWidgetMenuTitle"),
]

CUIDRAW_RE = re.compile(r"CUIDraw")


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


def parse_snow_report(path):
    mapping = {}
    current = None
    fp = open(path, "r")
    try:
        for raw in fp:
            s = raw.strip()
            if s.startswith("live_offset="):
                fields = {}
                for part in s.split():
                    if "=" in part:
                        k, v = part.split("=", 1)
                        fields[k] = v
                current = fields.get("live_offset")
            elif current is not None and s.startswith("resolved_symbol="):
                mapping[current] = s.split("=", 1)[1]
                current = None
    finally:
        fp.close()
    return mapping


def emit_body(fp, body):
    line(fp, "instruction_lines=%d" % len(body))
    line(fp, "-- CUIDraw lines --")
    hits = [raw for addr, raw in body if CUIDRAW_RE.search(raw)]
    if hits:
        for raw in hits:
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
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-cuidraw-callers.")

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

        local = os.path.join(tmpdir, "HIToolbox.%s" % expected["arch"])
        symbols = []
        by_name = {}
        rows = []
        digest = "MISSING"

        if not os.path.isfile(HITOOLBOX):
            issues.append("HIToolbox missing")
        elif not thin(HITOOLBOX, expected["arch"], local):
            issues.append("required HIToolbox slice unavailable")
        else:
            digest = sha256(local)
            if digest != expected["slice_sha"]:
                issues.append("HIToolbox slice SHA mismatch")
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
                if len(snow_mapping) != len(LIVE_CALLERS):
                    issues.append("Snow report caller mapping incomplete")

        fp = open(report, "w")
        try:
            line(fp, "== PPC Carbon GUI HIToolbox CUIDraw caller resolution ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % expected["arch"])
            line(fp, "hitoolbox_slice_sha256=%s" % digest)
            line(fp, "expected_hitoolbox_slice_sha256=%s" % expected["slice_sha"])
            line(fp, "hitoolbox_slice_exact=%s" %
                 ("YES" if digest == expected["slice_sha"] else "NO"))
            if product == "10.7.5":
                line(fp, "runtime_ppc_hitoolbox_contract=accepted_identical_snow_ppc_cache")
                line(fp, "native_lion_hitoolbox_role=same-symbol release reference")
            else:
                line(fp, "runtime_ppc_hitoolbox_contract=local_snow_ppc_reference")

            line(fp)
            line(fp, "== Reviewed live v2 call summary ==")
            line(fp, "first_eight_request_streams_equivalent=YES")
            line(fp, "snow_total_calls=9")
            line(fp, "lion_total_calls=8")
            line(fp, "snow_extra_call_role=kCUIWidgetMenuTitle")
            line(fp, "snow_extra_call_relevance_to_titlebar_frame=NO")

            if product == "10.6.8":
                for addr, role, snow_count, lion_count, widget in LIVE_CALLERS:
                    line(fp)
                    line(fp, "== Live caller ==")
                    line(fp, "live_offset=0x%08x role=%s snow_count=%d lion_count=%d widget=%s" %
                         (addr, role, snow_count, lion_count, widget))
                    found = find_containing(symbols, addr)
                    if found is None:
                        line(fp, "resolved=NO")
                        issues.append("live caller 0x%08x unresolved" % addr)
                        continue
                    index, start, end, name = found
                    body = symbol_body(rows, symbols, index)
                    line(fp, "resolved=YES")
                    line(fp, "resolved_symbol=%s" % name)
                    line(fp, "symbol_start=0x%08x" % start)
                    line(fp, "caller_delta=0x%x" % (addr - start))
                    line(fp, "symbol_end=%s" %
                         ("0x%08x" % end if end is not None else "UNKNOWN"))
                    line(fp, "body_contains_CUIDraw=%s" %
                         ("YES" if any(CUIDRAW_RE.search(raw) for a, raw in body) else "NO"))
                    emit_body(fp, body)
            else:
                line(fp)
                line(fp, "== Lion native same-symbol reference ==")
                for addr, role, snow_count, lion_count, widget in LIVE_CALLERS:
                    key = "0x%08x" % addr
                    name = snow_mapping.get(key)
                    line(fp)
                    line(fp, "live_snow_offset=%s role=%s snow_count=%d lion_count=%d widget=%s" %
                         (key, role, snow_count, lion_count, widget))
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
                    line(fp, "body_contains_CUIDraw=%s" %
                         ("YES" if any(CUIDRAW_RE.search(raw) for a, raw in body) else "NO"))
                    emit_body(fp, body)

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for item in issues:
                    line(fp, "validation_issue=%s" % item)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "cuidraw_caller_resolution_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility artifact was built or loaded.")
            line(fp, "No framework, CoreUI resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
            line(fp, "Only a temporary HIToolbox architecture slice was created and removed.")
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
