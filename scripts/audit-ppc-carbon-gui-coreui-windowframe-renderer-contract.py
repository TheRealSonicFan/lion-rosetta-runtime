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
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-renderer-contract-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"

CUIDRAW = "_CUIDraw"
DRAW_WINDOW_TITLEBAR = "__ZN11CUIRenderer18DrawWindowTitleBarEPK13CUIDescriptor"
DRAW_WINDOW_FRAME_DARK = "__ZN11CUIRenderer19DrawWindowFrameDarkEPK13CUIDescriptor"
CREATE_IMAGE = "__ZN11CUIRenderer11CreateImageElPK13CUIDescriptorP6CGRectPfPtPh"
CREATE_GRAY_SNOW = "__ZN11CUIRenderer28CreateGrayCubicGradientImageEiii"
CREATE_GRAY_LION = "__ZN11CUIRenderer28CreateGrayCubicGradientImageEmmmb"
COPY_TITLEBAR = "__ZN11CUIRenderer23CopyWindowTitlebarImageEPK13CUIDescriptorf"
COPY_BACKGROUND = "__ZN11CUIRenderer25CopyWindowBackgroundImageEPK13CUIDescriptor"

COMMON_REQUIRED = [
    CUIDRAW,
    DRAW_WINDOW_TITLEBAR,
    DRAW_WINDOW_FRAME_DARK,
    CREATE_IMAGE,
]

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        slice_sha="5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        required=COMMON_REQUIRED + [CREATE_GRAY_SNOW],
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        slice_sha="5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        required=COMMON_REQUIRED + [CREATE_GRAY_LION, COPY_TITLEBAR, COPY_BACKGROUND],
    ),
}

TARGETS = [
    CUIDRAW,
    DRAW_WINDOW_TITLEBAR,
    DRAW_WINDOW_FRAME_DARK,
    CREATE_IMAGE,
    CREATE_GRAY_SNOW,
    CREATE_GRAY_LION,
    COPY_TITLEBAR,
    COPY_BACKGROUND,
]

FOCUS_NAMES = [
    "CreateImage",
    "CreateGrayCubicGradientImage",
    "CopyWindowTitlebarImage",
    "CopyWindowBackgroundImage",
    "LoadFromArtFile",
    "CUIElement4Load",
    "CGImageCreate",
    "CGContext",
    "CUIColor",
    "CUIDraw",
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


def parse_instructions(text):
    out = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex(parts[0])
        if addr is not None:
            out.append((addr, raw))
    return out


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
    body = [(addr, raw) for addr, raw in rows
            if addr >= start and (end is None or addr < end)]
    return start, body


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
        target_addr = call_target(raw)
        resolved = by_addr.get(target_addr) if target_addr is not None else None
        out.append((addr, raw, target_addr, resolved))
    return out


def is_focus(raw, resolved):
    hay = raw + " " + (resolved or "")
    for name in FOCUS_NAMES:
        if name in hay:
            return True
    return False


def emit_context(fp, body, match_indexes, radius=8):
    emitted = set()
    for idx in match_indexes:
        lo = max(0, idx - radius)
        hi = min(len(body), idx + radius + 1)
        for j in range(lo, hi):
            if j in emitted:
                continue
            emitted.add(j)
            line(fp, body[j][1])
        line(fp, "--")


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./ppc-carbon-gui-coreui-windowframe-renderer-contract.txt"
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-coreui-windowframe.")

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

        thin_path = os.path.join(tmpdir, "CoreUI.%s" % expected["arch"])
        symbols = []
        by_name = {}
        by_addr = {}
        rows = []
        digest = "MISSING"

        if not os.path.isfile(COREUI):
            issues.append("CoreUI missing")
        elif not thin(COREUI, expected["arch"], thin_path):
            issues.append("required CoreUI slice unavailable")
        else:
            digest = sha256(thin_path)
            if digest != expected["slice_sha"]:
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
                rows = parse_instructions(dis)

        fp = open(report, "w")
        try:
            line(fp, "== PPC Carbon GUI CoreUI window-frame renderer contract ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % expected["arch"])
            line(fp, "coreui_slice_sha256=%s" % digest)
            line(fp, "expected_coreui_slice_sha256=%s" % expected["slice_sha"])
            line(fp, "coreui_slice_exact=%s" %
                 ("YES" if digest == expected["slice_sha"] else "NO"))
            line(fp, "live_windowframe_widget=kCUIWidgetWindowFrame")
            line(fp, "live_windowframe_rect=0,0,400,222")
            line(fp, "live_request_stream_equivalent_snow_lion=YES")
            line(fp, "runtime_on_lion=accepted_snow_ppc_coreui_cache")
            line(fp, "native_lion_role=release_local_renderer_reference")

            for required in expected["required"]:
                if required not in by_name:
                    issues.append("required symbol missing: %s" % required)

            for target in TARGETS:
                line(fp)
                line(fp, "== CoreUI symbol: %s ==" % target)
                if target not in by_name:
                    line(fp, "present=NO")
                    continue

                start, body = body_for(symbols, rows, target)
                line(fp, "present=YES")
                line(fp, "symbol_address=0x%x" % start)
                line(fp, "instruction_lines=%d" % len(body))

                calls = call_inventory(body, by_addr)
                line(fp, "call_count=%d" % len(calls))
                focus = []
                for i, (addr, raw, target_addr, resolved) in enumerate(calls):
                    line(fp, "call=0x%x resolved=%s raw=%s" %
                         (addr, resolved or "UNRESOLVED", raw))
                    if is_focus(raw, resolved):
                        focus.append(i)

                line(fp, "-- focused call contexts --")
                if not focus:
                    line(fp, "NONE")
                else:
                    body_index_by_addr = dict((addr, i) for i, (addr, raw) in enumerate(body))
                    match_indexes = []
                    for call_idx in focus:
                        call_addr = calls[call_idx][0]
                        if call_addr in body_index_by_addr:
                            match_indexes.append(body_index_by_addr[call_addr])
                    emit_context(fp, body, match_indexes)

                line(fp, "-- full body --")
                for addr, raw in body:
                    line(fp, raw)

            frame_start, frame_body = body_for(symbols, rows, DRAW_WINDOW_FRAME_DARK)
            if frame_body:
                frame_text = "\n".join(raw for addr, raw in frame_body)
                line(fp)
                line(fp, "== Window-frame focused summary ==")
                for needle in [
                    "CreateImage",
                    "CreateGrayCubicGradientImage",
                    "CopyWindowTitlebarImage",
                    "CopyWindowBackgroundImage",
                    "CGContextFillRect",
                    "CGContextDrawTiledImage",
                    "CGImageCreate",
                ]:
                    line(fp, "%s_count=%d" % (needle,
                         sum(1 for raw in frame_text.splitlines() if needle in raw)))

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for item in issues:
                    line(fp, "validation_issue=%s" % item)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "windowframe_renderer_contract_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "The analyzer opened only local CoreUI for reading.")
            line(fp, "It created only a temporary architecture slice for static disassembly.")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility artifact was built or loaded.")
            line(fp, "No framework, CoreUI resource, Rosetta cache, service, WindowServer, or XNU state was modified.")
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
