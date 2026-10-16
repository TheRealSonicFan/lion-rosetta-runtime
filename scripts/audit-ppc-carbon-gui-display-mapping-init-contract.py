#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-mapping-init-contract-v1"

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

COMMON_TARGETS = [
    "_CGSMainDisplayID",
    "_lookupMainDisplay",
    "_updateAllDisplayInfoAsNeeded",
    "_CGSDisplayMappingChangedSeed",
    "_CGSDisplayChangedSeed",
    "_CGSGetNumberOfDisplays",
    "__CGSGetNumberOfDisplays",
    "_CGSGetDisplayList",
    "_CGSGetActiveDisplayList",
    "__CGSDisplayInitialize",
    "_CGSDisplayNotifyProc",
]

SNOW_TARGETS = [
    "_initCGDisplayMappings",
    "_initCGDisplayState",
    "_bindDisplayMapping",
]

LION_TARGETS = [
    "_initDisplayMappings",
    "_initDisplayState",
    "_addEntryForDisplay",
    "_lookupDisplayNumber",
]

FAMILY_PATTERNS = [
    ("mapping_init", re.compile(r"(initCGDisplayMappings|initDisplayMappings|initCGDisplayState|initDisplayState)$", re.I)),
    ("mapping_bind", re.compile(r"(bindDisplayMapping|addEntryForDisplay)$", re.I)),
    ("mapping_seed", re.compile(r"CGSDisplay(Mapping)?ChangedSeed$", re.I)),
    ("display_lookup", re.compile(r"(lookupMainDisplay|lookupDisplayNumber|lookupDisplay)$", re.I)),
    ("display_inventory", re.compile(r"CGS(GetNumberOfDisplays|GetDisplayList|GetActiveDisplayList)$", re.I)),
    ("display_notify", re.compile(r"(CGSDisplayNotifyProc|CGSDisplayInitialize)$", re.I)),
]

TRANSPORT_RE = re.compile(
    r"(mach_msg|mig_get_reply_port|mig_put_reply_port|mig_dealloc_reply_port|"
    r"vm_map|vm_remap|vm_allocate|vm_deallocate|mmap|munmap|syscall|"
    r"bootstrap|CGS.*(Server|Port)|0x00001513|0x1513|"
    r"0x00007[0-9a-fA-F]{2}|0x7[0-9a-fA-F]{3})",
    re.I,
)

CALL_RE = re.compile(r"\b(bl|b|calll|callq|jmp)\b", re.I)

FOCUS_STRING_RE = re.compile(
    r"(display info mapping|display mapping|Cannot get displays|"
    r"CGSMainDisplayID|CGSGetDisplayList|CGSGetNumberOfDisplays|"
    r"CGSGetActiveDisplayList|Invalid display)",
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

def direct_references(symbols, groups, target_idx):
    addr, name, raw = symbols[target_idx]
    forms = ["0x%x" % addr, "0x%08x" % addr]
    low_name = name.lower()
    hits = []
    for idx, selected in groups.items():
        if idx == target_idx:
            continue
        for call_addr, call_raw in selected:
            low = call_raw.lower()
            if low_name in low or any(form.lower() in low for form in forms):
                hits.append((idx, call_addr, call_raw))
    return hits

def emit_symbol(fp, label, symbols, groups, idx):
    addr, name, raw = symbols[idx]
    selected = groups.get(idx, [])
    transport = [r for a, r in selected if TRANSPORT_RE.search(r)]
    calls = [r for a, r in selected if CALL_RE.search(r)]
    refs = direct_references(symbols, groups, idx)

    line(fp)
    line(fp, "== %s: %s ==" % (label, name))
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "symbol_record=%s" % raw)
    line(fp, "instruction_lines=%d" % len(selected))
    line(fp, "call_or_branch_line_count=%d" % len(calls))
    line(fp, "transport_candidate_line_count=%d" % len(transport))
    for a, r in selected:
        line(fp, r)

    line(fp, "-- call/branch subset --")
    if calls:
        for r in calls:
            line(fp, r)
    else:
        line(fp, "NONE")

    line(fp, "-- transport candidate subset --")
    if transport:
        for r in transport:
            line(fp, r)
    else:
        line(fp, "NONE")

    line(fp, "direct_reference_count=%d" % len(refs))
    for caller_idx, call_addr, call_raw in refs[:400]:
        line(fp, "caller=%s@0x%x call_site=0x%x raw=%s" %
             (symbols[caller_idx][1], symbols[caller_idx][0], call_addr, call_raw))

def emit_strings(fp, path):
    rc, out = run(["/usr/bin/strings", "-a", path])
    line(fp)
    line(fp, "== Focused strings ==")
    if rc != 0:
        line(fp, "strings_failed")
        return
    hits = [s for s in out.splitlines() if FOCUS_STRING_RE.search(s)]
    line(fp, "focused_string_count=%d" % len(hits))
    for s in hits[:1000]:
        line(fp, s)

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-mapping-init.")

    try:
        rc, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip() if rc == 0 else "UNKNOWN"
        rc, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip() if rc == 0 else "UNKNOWN"

        if product == SNOW_PRODUCT and build == SNOW_BUILD:
            mode = "snow"
            arch = SNOW_ARCH
            release_targets = SNOW_TARGETS
        elif product == LION_PRODUCT and build == LION_BUILD:
            mode = "lion"
            arch = LION_ARCH
            release_targets = LION_TARGETS
        else:
            mode = "unsupported"
            arch = None
            release_targets = []
            issues.append("unsupported product/build: %s/%s" % (product, build))

        with open(report, "w") as fp:
            line(fp, "== PPC Carbon GUI display-mapping init contract audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "live_lion_main_display_fallback_result=0")
            line(fp, "live_lion_display0_diagnostic_count=8")
            line(fp, "snow_main_display_lookup_init=_initCGDisplayMappings")
            line(fp, "lion_main_display_lookup_init=_initDisplayMappings")
            line(fp, "legacy_generated_get_number_of_displays_live_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
            line(fp, "display_mapping_patch_authorized=NO")
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
                    symbols = []
                    groups = {}
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
                            line(fp, "%s@0x%x" %
                                 (symbols[idx][1], symbols[idx][0]))

                    targets = COMMON_TARGETS + release_targets
                    for name in targets:
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

                    required = [
                        "_CGSMainDisplayID",
                        "_lookupMainDisplay",
                        "_updateAllDisplayInfoAsNeeded",
                    ] + release_targets
                    for name in required:
                        if not exact_indices(symbols, name):
                            issues.append("required target missing: %s" % name)

            line(fp)
            line(fp, "== Comparison questions ==")
            line(fp, "question_1=What concrete state object or shared mapping does each release initializer create?")
            line(fp, "question_2=Which call first obtains that state from WindowServer or another process boundary?")
            line(fp, "question_3=Are the Snow and Lion mapping-state transport contracts the same, shifted, or structurally different?")
            line(fp, "question_4=What exact condition makes Snow lookupMainDisplay return NULL and therefore CGSMainDisplayID return 0?")
            line(fp, "question_5=Does any generated __CGSGetNumberOfDisplays transport participate in the live main-display path, or is it unreferenced/deferred?")
            line(fp, "question_6=Which single next live boundary can observe mapping initialization without rewriting a display ID?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_mapping_init_contract_audit_exact=YES")
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
