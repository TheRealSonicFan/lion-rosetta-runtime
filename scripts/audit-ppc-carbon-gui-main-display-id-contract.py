#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-main-display-id-contract-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

SNOW_PRODUCT = "10.6.8"
SNOW_BUILD = "10K549"
LION_PRODUCT = "10.7.5"
LION_BUILD = "11G63"
SNOW_ARCH = "ppc7400"
LION_ARCH = "i386"

EXPECTED_SLICE = {
    "snow": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
    "lion": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
}

EXACT_TARGETS = [
    "_CGMainDisplayID",
    "_CGSMainDisplayID",
    "_CGSGetDisplayBounds",
    "_CGSGetUnflippedEventLocation",
    "_CGSMainConnectionID",
    "_lookupMainDisplay",
    "_lookupDisplayNumber",
    "_lookupDisplay",
    "_updateAllDisplayInfoAsNeeded",
    "_CGSInitialize",
    "__CGSDisplayInitialize",
    "_CGBDSBuildDisplayList",
    "_CGSGetNumberOfDisplays",
    "_CGSGetDisplayList",
    "_CGSGetOnlineDisplayList",
    "_CGSGetActiveDisplayList",
]

FAMILY_PATTERNS = [
    ("main_display", re.compile(r"(CGS?MainDisplayID|lookupMainDisplay|lookupDisplayNumber)$", re.I)),
    ("display_lookup", re.compile(r"(^|_)(lookupDisplay|findDisplay|initDisplays|initDisplayMappings)$", re.I)),
    ("display_update", re.compile(r"(updateAllDisplayInfoAsNeeded|CGSDisplayInitialize|CGBDSBuildDisplayList)$", re.I)),
    ("display_inventory", re.compile(r"CGS(GetNumberOfDisplays|GetDisplayList|GetOnlineDisplayList|GetActiveDisplayList)$", re.I)),
    ("display_bounds", re.compile(r"CGSGetDisplayBounds$", re.I)),
    ("event_location", re.compile(r"CGSGetUnflippedEventLocation$", re.I)),
    ("connection", re.compile(r"CGSMainConnectionID$", re.I)),
]

FOCUS_STRING_RE = re.compile(
    r"(CGSMainDisplayID|MainDisplay|lookupMainDisplay|GetDisplayBounds|"
    r"Invalid display|DisplayID|display mapping|display info|Cannot get displays)",
    re.I,
)

PROTOCOL_RE = re.compile(
    r"(mach_msg|mig_get_reply_port|mig_put_reply_port|mig_dealloc_reply_port|"
    r"0x00007[0-9a-fA-F]{2}|0x7[0-9a-fA-F]{3}|0x00001513|0x1513)",
    re.I,
)

def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out

def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]

def line(fp, value=""):
    fp.write(value)
    fp.write("\n")

def parse_hex(token):
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
        return True, out
    rc2, out2 = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    if rc2 == 0:
        return True, out2
    return False, out2 if out2.strip() else out

def thin(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out

def parse_symbols(text):
    result = []
    for raw in text.splitlines():
        if "(__TEXT,__text)" not in raw:
            continue
        parts = raw.split()
        if len(parts) < 2:
            continue
        addr = parse_hex(parts[0])
        if addr is None:
            continue
        result.append((addr, parts[-1], raw))
    result.sort()
    return result

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

def group_rows(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for addr, raw in rows:
        while si + 1 < len(symbols) and symbols[si + 1][0] <= addr:
            si += 1
        if symbols[si][0] <= addr:
            groups.setdefault(si, []).append((addr, raw))
    return groups

def exact_indices(symbols, name):
    return [i for i, item in enumerate(symbols) if item[1] == name]

def matching_indices(symbols, pattern):
    return [i for i, item in enumerate(symbols) if pattern.search(item[1])]

def emit_callers(fp, symbols, groups, target_idx):
    addr, name, raw = symbols[target_idx]
    forms = ["0x%x" % addr, "0x%08x" % addr]
    name_lower = name.lower()
    hits = []
    for idx, selected in groups.items():
        if idx == target_idx:
            continue
        for call_addr, call_raw in selected:
            low = call_raw.lower()
            if name_lower in low or any(form.lower() in low for form in forms):
                hits.append((idx, call_addr, call_raw))
    line(fp, "direct_reference_count=%d" % len(hits))
    for idx, call_addr, call_raw in hits[:320]:
        line(fp, "caller=%s@0x%x call_site=0x%x raw=%s" %
             (symbols[idx][1], symbols[idx][0], call_addr, call_raw))

def emit_symbol(fp, label, symbols, groups, idx):
    addr, name, raw = symbols[idx]
    selected = groups.get(idx, [])
    line(fp)
    line(fp, "== %s: %s ==" % (label, name))
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "symbol_record=%s" % raw)
    line(fp, "instruction_lines=%d" % len(selected))
    transport = [r for a, r in selected if PROTOCOL_RE.search(r)]
    line(fp, "protocol_or_transport_line_count=%d" % len(transport))
    for a, r in selected:
        line(fp, r)
    line(fp, "-- protocol/transport subset --")
    if transport:
        for r in transport:
            line(fp, r)
    else:
        line(fp, "NONE")
    emit_callers(fp, symbols, groups, idx)

def emit_strings(fp, path):
    rc, out = run(["/usr/bin/strings", "-a", path])
    line(fp)
    line(fp, "== Focused strings ==")
    if rc != 0:
        line(fp, "strings_failed")
        return
    hits = [x for x in out.splitlines() if FOCUS_STRING_RE.search(x)]
    line(fp, "focused_string_count=%d" % len(hits))
    for x in hits[:1000]:
        line(fp, x)

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-main-display-id.")

    try:
        rc, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip() if rc == 0 else "UNKNOWN"
        rc, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip() if rc == 0 else "UNKNOWN"

        if product == SNOW_PRODUCT and build == SNOW_BUILD:
            mode = "snow"
            arch = SNOW_ARCH
        elif product == LION_PRODUCT and build == LION_BUILD:
            mode = "lion"
            arch = LION_ARCH
        else:
            mode = "unsupported"
            arch = None
            issues.append("unsupported product/build: %s/%s" % (product, build))

        with open(report, "w") as fp:
            line(fp, "== PPC Carbon GUI main-display ID contract audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "live_lion_display0_diagnostic_count=8")
            line(fp, "live_lion_first_titlebar_mouse_down=302,109,inDrag")
            line(fp, "live_lion_first_move_delta=-302,-98")
            line(fp, "snow_event_location_xy_offsets=0x0c,0x10")
            line(fp, "lion_event_location_xy_offsets=0x0c,0x10")
            line(fp, "snow_event_cached_vertical_extent_offset=0x00c6")
            line(fp, "lion_event_cached_vertical_extent_offset=0x00be")
            line(fp, "snow_zero_cache_fallback=_CGSMainDisplayID_then_CGSGetDisplayBounds")
            line(fp, "display_id_normalization_authorized=NO")
            line(fp, "event_payload_rewrite_authorized=NO")
            line(fp, "move_payload_rewrite_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            line(fp)
            line(fp, "== Rosetta shared-cache provenance ==")
            if os.path.isfile(ROSETTA_CACHE):
                line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
            else:
                line(fp, "rosetta_cache=MISSING")
            if os.path.isfile(ROSETTA_MAP):
                line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
                try:
                    data = open(ROSETTA_MAP, "r").read()
                    line(fp, "cache_map_contains_coregraphics=%s" %
                         ("YES" if COREGRAPHICS in data else "NO"))
                except IOError as e:
                    line(fp, "rosetta_cache_map_read_error=%s" % e)
            else:
                line(fp, "rosetta_cache_map=MISSING")

            line(fp)
            line(fp, "== CoreGraphics ==")
            line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                line(fp, "state=MISSING")
                issues.append("CoreGraphics missing")
            elif arch is not None:
                line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                rc, out = run(["/usr/bin/file", COREGRAPHICS])
                line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREGRAPHICS])
                line(fp, out.rstrip())

                dst = os.path.join(tempdir, "CoreGraphics." + arch)
                ok, out = thin(COREGRAPHICS, arch, dst)
                line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing")
                else:
                    slice_hash = sha256(dst)
                    line(fp, "slice_sha256=%s" % slice_hash)
                    line(fp, "slice_exact=%s" %
                         ("YES" if slice_hash == EXPECTED_SLICE[mode] else "NO"))
                    if slice_hash != EXPECTED_SLICE[mode]:
                        issues.append("CoreGraphics slice SHA-256 mismatch")

                    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                    if rc != 0:
                        line(fp, "nm_failed")
                        line(fp, nm_out.rstrip())
                        issues.append("nm failed")
                        symbols = []
                    else:
                        symbols = parse_symbols(nm_out)
                        line(fp, "parsed_text_symbols=%d" % len(symbols))

                    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                    if rc != 0:
                        line(fp, "otool_disassembly_failed")
                        line(fp, dis_out.rstrip())
                        issues.append("otool disassembly failed")
                        rows = []
                        groups = {}
                    else:
                        rows = parse_rows(dis_out)
                        groups = group_rows(rows, symbols)
                        line(fp, "parsed_instruction_lines=%d" % len(rows))

                    emit_strings(fp, dst)

                    line(fp)
                    line(fp, "== Focused symbol inventory ==")
                    emitted = set()
                    for family, pattern in FAMILY_PATTERNS:
                        idxs = matching_indices(symbols, pattern)
                        line(fp, "%s_symbol_count=%d" % (family, len(idxs)))
                        for idx in idxs:
                            line(fp, "%s@0x%x" % (symbols[idx][1], symbols[idx][0]))

                    for name in EXACT_TARGETS:
                        idxs = exact_indices(symbols, name)
                        line(fp)
                        line(fp, "exact_target=%s count=%d" % (name, len(idxs)))
                        for idx in idxs:
                            if idx in emitted:
                                continue
                            emitted.add(idx)
                            emit_symbol(fp, "CoreGraphics target", symbols, groups, idx)

                    for family, pattern in FAMILY_PATTERNS:
                        for idx in matching_indices(symbols, pattern):
                            if idx in emitted:
                                continue
                            emitted.add(idx)
                            emit_symbol(fp, "CoreGraphics family " + family,
                                        symbols, groups, idx)

                    for required in (
                        "_CGSMainDisplayID",
                        "_lookupMainDisplay",
                        "_updateAllDisplayInfoAsNeeded",
                        "_CGSGetDisplayBounds",
                        "_CGSGetUnflippedEventLocation",
                    ):
                        if not exact_indices(symbols, required):
                            issues.append("required target missing: %s" % required)

            line(fp)
            line(fp, "== Comparison questions ==")
            line(fp, "question_1=What value source does CGSMainDisplayID return on each release?")
            line(fp, "question_2=Does lookupMainDisplay depend on release-local shared mappings, server queries, or both?")
            line(fp, "question_3=Which initializer populates the Snow PPC main-display mapping consumed during event-coordinate unflipping?")
            line(fp, "question_4=Did Lion replace the Snow PPC main-display lookup contract with lookupDisplayNumber or a different mapping representation?")
            line(fp, "question_5=Is there a narrow generated-MIG/display-state boundary suitable for live observation before any compatibility rewrite?")
            line(fp, "note=The 0xc6 Snow / 0xbe Lion event field is a cached vertical extent populated after successful display-bounds lookup; it is not treated here as a display ID.")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "main_display_id_contract_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No display, CGS, WindowServer, Mach, bootstrap, mouse, or notification request was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")
            line(fp, "No CoreGraphics, Rosetta cache, WindowServer, dyld, or XNU state was modified.")
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)

    return 1 if issues else 0

if __name__ == "__main__":
    sys.exit(main())
