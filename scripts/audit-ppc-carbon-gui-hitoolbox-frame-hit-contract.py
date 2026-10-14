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
AUDIT_CONTRACT = "carbon-gui-hitoolbox-frame-hit-contract-v1"

HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_CACHE_SHA = "2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_MAP_SHA = "66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        slice_sha="fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f",
        frame_internal="__Z31_HIThemeDrawWindowFrameInternalPK6CGRectPK21HIThemeWindowDrawInfoP22WindowTitleDrawingXUPPmP9CGContextmPS_",
        document_coreui="__Z36_HIThemeDrawDocumentWindowWithCoreUIPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_",
        addresses={
            "_HIThemeGetWindowRegionHit": 0x1f674,
            "_HIThemeGetWindowShape": 0x1fa8c,
            "__Z25_HIThemeDrawMovableWindowPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_": 0x20fac,
            "__Z26_HIThemeDrawDocumentWindowPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_": 0x21248,
            "__Z36_HIThemeDrawDocumentWindowWithCoreUIPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_": 0x2161c,
            "__Z31_HIThemeDrawWindowFrameInternalPK6CGRectPK21HIThemeWindowDrawInfoP22WindowTitleDrawingXUPPmP9CGContextmPS_": 0x21c10,
            "_HIThemeDrawWindowFrame": 0x220dc,
            "__ZN12LayoutEngine9HitLayoutEP6TThemePvRK6CGRectPKlm7CGPointPKmRm": 0x26f18,
            "__ZN12LayoutEngine21ApplyLayoutBackgroundEP6TThemePvRK6CGRectPKlmshPKmP9CGContext": 0x27118,
            "__ZN12LayoutEngine10DrawLayoutEP6TThemePvRK6CGRecttPKlmPKmP9CGContexts": 0x27368,
            "__ZN14ThemeWindowDef14ClearStructureEP13OpaqueGrafPtrP9CGContext": 0x2e7fe4,
            "__ZN14ThemeWindowDef20InitializeWindowDataEv": 0x2e8b48,
            "__ZN14ThemeWindowDef31SetupTrackingRectForWidgetGroupEm": 0x2e827c,
            "__ZN14ThemeWindowDef17CopyShapeInternalEtPPK9__HIShapePK6CGRecth": 0x2e9540,
            "__ZN14ThemeWindowDef9CopyShapeEtPPK9__HIShapePK6CGRect": 0x2e99ac,
            "__ZN14ThemeWindowDef7HitSelfE5Point": 0x2e99b4,
            "__ZN14ThemeWindowDef9DrawFrameEv": 0x2ea074,
        },
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        slice_sha="b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6",
        frame_internal="__ZL31_HIThemeDrawWindowFrameInternalPK6CGRectPK21HIThemeWindowDrawInfoP22WindowTitleDrawingXUPPmP9CGContextmPS_",
        document_coreui=None,
        addresses={
            "_HIThemeGetWindowRegionHit": 0x7d885,
            "_HIThemeGetWindowShape": 0x7db5e,
            "__Z25_HIThemeDrawMovableWindowPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_": 0x7f580,
            "__Z26_HIThemeDrawDocumentWindowPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_": 0x7f882,
            "__ZL31_HIThemeDrawWindowFrameInternalPK6CGRectPK21HIThemeWindowDrawInfoP22WindowTitleDrawingXUPPmP9CGContextmPS_": 0x7fd02,
            "_HIThemeDrawWindowFrame": 0x808e8,
            "__ZN12LayoutEngine9HitLayoutEP6TThemePvRK6CGRectPKlm7CGPointPKmRm": 0x837fc,
            "__ZN12LayoutEngine21ApplyLayoutBackgroundEP6TThemePvRK6CGRectPKlmshPKmP9CGContext": 0x850e8,
            "__ZN12LayoutEngine10DrawLayoutEP6TThemePvRK6CGRecttPKlmPKmP9CGContexts": 0x859c0,
            "__ZN14ThemeWindowDef14ClearStructureEP13OpaqueGrafPtrP9CGContext": 0x2ebcae,
            "__ZN14ThemeWindowDef20InitializeWindowDataEv": 0x2eb664,
            "__ZN14ThemeWindowDef31SetupTrackingRectForWidgetGroupEm": 0x2ec182,
            "__ZN14ThemeWindowDef7HitSelfE5Point": 0x2eb8d4,
            "__ZN14ThemeWindowDef9DrawFrameEv": 0x2ebddc,
        },
    ),
}

OPTIONAL_NAMES = [
    "_GetThemeWindowRegion",
    "_GetThemeWindowRegionHit",
    "_GetWindowRegion",
    "_FindWindow",
    "_DragWindow",
    "__Z30_HIThemeGetWindowShapeInternalPK6CGRectPK21HIThemeWindowDrawInfotP15OpaqueRgnHandle",
    "__ZN14ThemeWindowDef22DrawWidgetFromPartCodeEsmmPv",
    "__ZN14ThemeWindowDef12StateChangedEm",
    "__ZN14ThemeWindowDef25CalcThemeWindowAttributesEv",
    "__ZN14ThemeWindowDef42AdjustMetricsAndPortStateForTruncatedTitleEs",
    "__ZN14ThemeWindowDef12GetGrowSidesE5Point",
    "__ZN14ThemeWindowDef12GetGrowSidesE5Pointm",
]

STRING_RE = re.compile(
    r"(HLTBUnrolledWindows|HIThemeDrawWindowFrame drawing with unrolled primitives|"
    r"titlebarcontrols|Appearance|com\.apple\.HIToolbox)",
    re.I,
)

BRANCH_RE = re.compile(r"\b(bl|bla|b|beq|bne|bc|call|calll|jmp|jmpl)\b", re.I)


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
            chunk = fp.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    finally:
        fp.close()
    return h.hexdigest()


def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")


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


def parse_symbols(text):
    ordered = []
    by_name = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in line:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        if name not in by_name:
            by_name[name] = addr
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, line))
    return rows


def symbol_rows(rows, symbols, index):
    start = symbols[index][0]
    end = symbols[index + 1][0] if index + 1 < len(symbols) else None
    out = []
    for addr, line in rows:
        if addr < start:
            continue
        if end is not None and addr >= end:
            break
        out.append((addr, line))
    return out


def body_sha(lines):
    text = "\n".join(line for addr, line in lines)
    if not isinstance(text, bytes):
        text = text.encode("utf-8")
    return hashlib.sha256(text).hexdigest()


def emit_symbol(fp, name, symbols, by_name, rows, required, expected_addr, issues):
    addr = by_name.get(name)
    write_line(fp)
    write_line(fp, "== target symbol ==")
    write_line(fp, "name=%s" % name)
    write_line(fp, "required=%s" % ("YES" if required else "NO"))
    write_line(fp, "present=%s" % ("YES" if addr is not None else "NO"))
    if addr is None:
        if required:
            issues.append("required symbol missing: %s" % name)
        return

    write_line(fp, "address=0x%x" % addr)
    if expected_addr is not None:
        write_line(fp, "expected_address=0x%x" % expected_addr)
        write_line(fp, "address_exact=%s" % ("YES" if addr == expected_addr else "NO"))
        if addr != expected_addr:
            issues.append("symbol address mismatch: %s" % name)

    index = None
    for i, item in enumerate(symbols):
        if item[0] == addr and item[1] == name:
            index = i
            break
    if index is None:
        issues.append("symbol index missing: %s" % name)
        return

    body = symbol_rows(rows, symbols, index)
    write_line(fp, "instruction_lines=%d" % len(body))
    write_line(fp, "body_text_sha256=%s" % body_sha(body))
    write_line(fp, "-- full body --")
    for row_addr, line in body:
        write_line(fp, line)
    write_line(fp, "-- call/branch lines --")
    hits = [line for row_addr, line in body if BRANCH_RE.search(line)]
    if hits:
        for line in hits:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./ppc-carbon-gui-hitoolbox-frame-hit-contract.txt"
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-hitoolbox-frame-hit.")

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
        if cache_sha != EXPECTED_CACHE_SHA:
            issues.append("Rosetta cache SHA mismatch")
        if map_sha != EXPECTED_MAP_SHA:
            issues.append("Rosetta cache map SHA mismatch")

        thin = os.path.join(tempdir, "HIToolbox.%s" % expected["arch"])
        slice_sha = "MISSING"
        symbols = []
        by_name = {}
        rows = []
        cstring_hits = []

        if not os.path.isfile(HITOOLBOX):
            issues.append("HIToolbox missing")
        elif not thin_arch(HITOOLBOX, expected["arch"], thin):
            issues.append("required HIToolbox slice unavailable")
        else:
            slice_sha = sha256(thin)
            if slice_sha != expected["slice_sha"]:
                issues.append("HIToolbox slice SHA mismatch")

            rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
            if rc != 0:
                issues.append("HIToolbox nm failed")
            else:
                symbols, by_name = parse_symbols(nm_out)

            rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
            if rc != 0:
                issues.append("HIToolbox disassembly failed")
            else:
                rows = parse_instructions(dis_out)

            rc, cs_out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
            if rc == 0:
                cstring_hits = [line for line in cs_out.splitlines() if STRING_RE.search(line)]
            else:
                issues.append("HIToolbox cstring dump failed")

        required_names = list(expected["addresses"].keys())
        optional_names = list(OPTIONAL_NAMES)
        other_internal = (
            "__ZL31_HIThemeDrawWindowFrameInternalPK6CGRectPK21HIThemeWindowDrawInfoP22WindowTitleDrawingXUPPmP9CGContextmPS_"
            if product == "10.6.8"
            else "__Z31_HIThemeDrawWindowFrameInternalPK6CGRectPK21HIThemeWindowDrawInfoP22WindowTitleDrawingXUPPmP9CGContextmPS_"
        )
        optional_names.append(other_internal)

        snow_coreui = "__Z36_HIThemeDrawDocumentWindowWithCoreUIPK6CGRectPK21HIThemeWindowDrawInfoP9CGContextPS_"
        document_coreui_present = snow_coreui in by_name
        if product == "10.6.8" and not document_coreui_present:
            issues.append("Snow DrawDocumentWindowWithCoreUI missing")
        if product == "10.7.5" and document_coreui_present:
            issues.append("unexpected Lion DrawDocumentWindowWithCoreUI symbol")

        use_unrolled_names = [
            name for name in by_name
            if "sUseUnrolledWindows" in name
        ]

        with open(report, "w") as fp:
            write_line(fp, "== PPC Carbon GUI HIToolbox frame/hit contract audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % expected["arch"])
            write_line(fp, "historical_ppc_runtime_source=dyld_shared_cache_rosetta")
            if product == "10.7.5":
                write_line(fp, "runtime_ppc_hitoolbox_contract=accepted_identical_snow_ppc_cache")
                write_line(fp, "native_lion_hitoolbox_role=reference_for_release_contract_only")
            else:
                write_line(fp, "runtime_ppc_hitoolbox_contract=local_snow_ppc_reference")

            write_line(fp)
            write_line(fp, "== Provenance ==")
            write_line(fp, "rosetta_cache_sha256=%s" % cache_sha)
            write_line(fp, "rosetta_cache_map_sha256=%s" % map_sha)
            write_line(fp, "hitoolbox_slice_sha256=%s" % slice_sha)
            write_line(fp, "expected_hitoolbox_slice_sha256=%s" % expected["slice_sha"])
            write_line(fp, "hitoolbox_slice_exact=%s" % ("YES" if slice_sha == expected["slice_sha"] else "NO"))

            write_line(fp)
            write_line(fp, "== Contract markers ==")
            write_line(fp, "frame_internal_symbol=%s" % expected["frame_internal"])
            write_line(fp, "document_window_with_coreui_present=%s" % ("YES" if document_coreui_present else "NO"))
            write_line(fp, "sUseUnrolledWindows_symbol_count=%d" % len(use_unrolled_names))
            for name in use_unrolled_names:
                write_line(fp, "sUseUnrolledWindows_symbol=%s address=0x%x" % (name, by_name[name]))
            write_line(fp, "focused_cstring_count=%d" % len(cstring_hits))
            for line in cstring_hits:
                write_line(fp, line)

            emitted = set()
            for name in required_names:
                emit_symbol(
                    fp, name, symbols, by_name, rows, True,
                    expected["addresses"].get(name), issues
                )
                emitted.add(name)

            for name in optional_names:
                if name in emitted:
                    continue
                emit_symbol(fp, name, symbols, by_name, rows, False, None, issues)
                emitted.add(name)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "frame_hit_contract_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No process was attached.")
            write_line(fp, "No compatibility dylib was built or loaded.")
            write_line(fp, "No HIToolbox/CoreUI resource, framework, Rosetta cache, WindowServer, service, or XNU state was modified.")
            write_line(fp, "Temporary HIToolbox architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        if issues:
            print("RESULT: FAIL")
            for issue in issues:
                print("validation_issue=%s" % issue)
            return 1
        print("RESULT: PASS")
        return 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
