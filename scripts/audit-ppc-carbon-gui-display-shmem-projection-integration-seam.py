#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-projection-integration-seam-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"

SNOW_PRODUCT = "10.6.8"
SNOW_BUILD = "10K549"
LION_PRODUCT = "10.7.5"
LION_BUILD = "11G63"
SNOW_ARCH = "ppc7400"
LION_ARCH = "i386"

EXPECTED = {
    "snow": {
        "coregraphics_slice": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "hitoolbox_slice": "fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f",
    },
    "lion": {
        "coregraphics_slice": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "hitoolbox_slice": "b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6",
    },
}

CORE_REQUIRED = [
    "_CGSMainDisplayID",
    "_CGSGetDisplayBounds",
    "_CGSGetUnflippedEventLocation",
]

CORE_OPTIONAL = [
    "_CGEventGetUnflippedLocation",
    "_CGEventGetUnflippedWindowLocation",
    "_CGSGetUnflippedWindowEventLocation",
    "_CGSGetWindowMouseLocation",
]

CANDIDATES = [
    "_CGEventGetUnflippedLocation",
    "_CGEventGetUnflippedWindowLocation",
    "_CGSGetUnflippedEventLocation",
    "_CGSGetUnflippedWindowEventLocation",
    "_CGSGetWindowMouseLocation",
    "_CGSMainDisplayID",
    "_CGSGetDisplayBounds",
]

TITLEBAR_RE = re.compile(
    r"(TrackMouseLocation|TWindowTracker|TDragTracker|DragWindow|"
    r"RelocateWindowImage|OnMouseMoved)",
    re.I,
)

CALL_RE = re.compile(r"\b(bl|b|calll|jmp)\b", re.I)

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

def undefined_imports(path):
    rc, out = run(["/usr/bin/nm", "-u", path])
    result = set()
    if rc != 0:
        return result, out
    for raw in out.splitlines():
        parts = raw.split()
        if parts:
            result.add(parts[-1])
    return result, out

def body_has_reference(symbols, groups, caller, target):
    idxs = exact_indices(symbols, caller)
    if len(idxs) != 1:
        return False, []
    hits = []
    for addr, raw in groups.get(idxs[0], []):
        if target in raw and CALL_RE.search(raw):
            hits.append((addr, raw))
    return bool(hits), hits

def emit_body(fp, label, symbols, groups, name):
    idxs = exact_indices(symbols, name)
    line(fp, "%s_count=%d" % (label, len(idxs)))
    for idx in idxs:
        addr, symbol, raw = symbols[idx]
        line(fp)
        line(fp, "== %s: %s ==" % (label, symbol))
        line(fp, "symbol_address=0x%x" % addr)
        line(fp, "symbol_record=%s" % raw)
        selected = groups.get(idx, [])
        line(fp, "instruction_lines=%d" % len(selected))
        for a, r in selected:
            line(fp, r)

def collect_candidate_calls(symbols, groups, imports, only_titlebar):
    hits = []
    for idx, selected in groups.items():
        caller = symbols[idx][1]
        if only_titlebar and not TITLEBAR_RE.search(caller):
            continue
        for addr, raw in selected:
            if not CALL_RE.search(raw):
                continue
            for candidate in CANDIDATES:
                if candidate in raw:
                    hits.append((
                        caller,
                        symbols[idx][0],
                        addr,
                        candidate,
                        "YES" if candidate in imports else "NO",
                        raw,
                    ))
    return hits

def analyze_image(fp, label, path, arch, expected_hash, tempdir, issues):
    line(fp)
    line(fp, "== %s ==" % label)
    line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        line(fp, "state=MISSING")
        issues.append("%s missing" % label)
        return None, None, set(), None

    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    line(fp, out.rstrip())

    dst = os.path.join(tempdir, label.replace(" ", "_") + "." + arch)
    ok, out = thin(path, arch, dst)
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        line(fp, out.rstrip())
        issues.append("%s required slice missing" % label)
        return None, None, set(), None

    slice_hash = sha256(dst)
    line(fp, "slice_sha256=%s" % slice_hash)
    line(fp, "slice_exact=%s" % ("YES" if slice_hash == expected_hash else "NO"))
    if slice_hash != expected_hash:
        issues.append("%s slice SHA-256 mismatch" % label)

    imports, import_out = undefined_imports(dst)
    line(fp, "undefined_symbol_count=%d" % len(imports))
    for candidate in CANDIDATES:
        line(fp, "candidate_import=%s present=%s" %
             (candidate, "YES" if candidate in imports else "NO"))

    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        line(fp, "nm_failed")
        line(fp, nm_out.rstrip())
        issues.append("%s nm failed" % label)
        return None, None, imports, dst

    symbols = parse_symbols(nm_out)
    line(fp, "parsed_text_symbols=%d" % len(symbols))

    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        line(fp, "otool_disassembly_failed")
        line(fp, dis_out.rstrip())
        issues.append("%s otool failed" % label)
        return symbols, None, imports, dst

    rows = parse_rows(dis_out)
    groups = group_rows(rows, symbols)
    line(fp, "parsed_instruction_lines=%d" % len(rows))
    return symbols, groups, imports, dst

def emit_hits(fp, title, hits):
    line(fp)
    line(fp, "== %s ==" % title)
    line(fp, "candidate_call_count=%d" % len(hits))
    for caller, caller_addr, call_addr, candidate, imported, raw in hits:
        line(fp,
             "candidate_call=%s caller=%s@0x%x call_site=0x%x imported=%s raw=%s" %
             (candidate, caller, caller_addr, call_addr, imported, raw))

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-projection-integration-seam.")

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
            line(fp, "== PPC Carbon GUI display-shmem projection integration-seam audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "prior_projection_proof_snow=PASS")
            line(fp, "prior_projection_proof_lion=PASS")
            line(fp, "server_owned_shared_record_write_authorized=NO")
            line(fp, "persistent_partial_projection_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "event_payload_rewrite_authorized=NO")
            line(fp, "coregraphics_text_patch_authorized=NO")
            line(fp, "live_interposer_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            if arch is not None:
                core_symbols, core_groups, core_imports, core_dst = analyze_image(
                    fp, "CoreGraphics", COREGRAPHICS, arch,
                    EXPECTED[mode]["coregraphics_slice"], tempdir, issues)
                hit_symbols, hit_groups, hit_imports, hit_dst = analyze_image(
                    fp, "HIToolbox", HITOOLBOX, arch,
                    EXPECTED[mode]["hitoolbox_slice"], tempdir, issues)

                line(fp)
                line(fp, "== CoreGraphics integration edge checks ==")
                if core_symbols is None or core_groups is None:
                    issues.append("CoreGraphics analysis unavailable")
                else:
                    for required in CORE_REQUIRED:
                        count = len(exact_indices(core_symbols, required))
                        line(fp, "core_target=%s count=%d" % (required, count))
                        if count != 1:
                            issues.append("required CoreGraphics target count %s=%d" %
                                          (required, count))

                    edge_a, hits_a = body_has_reference(
                        core_symbols, core_groups,
                        "_CGSGetUnflippedEventLocation", "_CGSMainDisplayID")
                    edge_b, hits_b = body_has_reference(
                        core_symbols, core_groups,
                        "_CGSGetUnflippedEventLocation", "_CGSGetDisplayBounds")
                    edge_c, hits_c = body_has_reference(
                        core_symbols, core_groups,
                        "_CGEventGetUnflippedLocation", "_CGSGetUnflippedEventLocation")

                    line(fp, "edge=_CGSGetUnflippedEventLocation->_CGSMainDisplayID present=%s binding=image-local" %
                         ("YES" if edge_a else "NO"))
                    for addr, raw in hits_a:
                        line(fp, "edge_site=0x%x raw=%s" % (addr, raw))

                    line(fp, "edge=_CGSGetUnflippedEventLocation->_CGSGetDisplayBounds present=%s binding=image-local" %
                         ("YES" if edge_b else "NO"))
                    for addr, raw in hits_b:
                        line(fp, "edge_site=0x%x raw=%s" % (addr, raw))

                    line(fp, "edge=_CGEventGetUnflippedLocation->_CGSGetUnflippedEventLocation present=%s binding=image-local" %
                         ("YES" if edge_c else "NO"))
                    for addr, raw in hits_c:
                        line(fp, "edge_site=0x%x raw=%s" % (addr, raw))

                    if mode == "snow":
                        if not edge_a:
                            issues.append("Snow zero-cache main-display edge missing")
                        if not edge_b:
                            issues.append("Snow zero-cache display-bounds edge missing")
                        if not edge_c:
                            issues.append("Snow public event-location wrapper edge missing")

                    for name in CORE_REQUIRED + CORE_OPTIONAL:
                        emit_body(fp, "CoreGraphics target", core_symbols, core_groups, name)

                if hit_symbols is None or hit_groups is None:
                    issues.append("HIToolbox analysis unavailable")
                else:
                    all_hits = collect_candidate_calls(
                        hit_symbols, hit_groups, hit_imports, False)
                    titlebar_hits = collect_candidate_calls(
                        hit_symbols, hit_groups, hit_imports, True)
                    emit_hits(fp, "HIToolbox all candidate call sites", all_hits)
                    emit_hits(fp, "HIToolbox titlebar-family candidate call sites",
                              titlebar_hits)

                    imported_titlebar = [x for x in titlebar_hits if x[4] == "YES"]
                    line(fp)
                    line(fp, "titlebar_imported_candidate_call_count=%d" %
                         len(imported_titlebar))
                    line(fp, "titlebar_imported_candidate_present=%s" %
                         ("YES" if imported_titlebar else "NO"))

                    line(fp)
                    line(fp, "== HIToolbox focused titlebar bodies ==")
                    focused = []
                    for idx, item in enumerate(hit_symbols):
                        if TITLEBAR_RE.search(item[1]):
                            focused.append(idx)
                    line(fp, "focused_titlebar_symbol_count=%d" % len(focused))
                    for idx in focused:
                        addr, name, raw = hit_symbols[idx]
                        line(fp)
                        line(fp, "titlebar_symbol=%s@0x%x" % (name, addr))
                        for a, r in hit_groups.get(idx, []):
                            if any(candidate in r for candidate in CANDIDATES):
                                line(fp, r)

            line(fp)
            line(fp, "== Interpretation questions ==")
            line(fp, "question_1=Which actual titlebar tracker call site first crosses from HIToolbox into a CoreGraphics event-location/display API through an imported symbol?")
            line(fp, "question_2=Is that call site interposable, unlike the image-local _CGSGetUnflippedEventLocation->_CGSMainDisplayID branch?")
            line(fp, "question_3=Can a future adapter reproduce only the zero-cache unflip fallback by obtaining the main display through the proven locked projection, restoring immediately, then querying bounds with the returned nonzero ID?")
            line(fp, "question_4=Would that adapter avoid leaving a partial projected record installed across _bindDisplayMapping, update/rebind, notification dispatch, or unlock?")
            line(fp, "question_5=If no imported titlebar seam encloses the failing fallback, must the project choose between a separately reviewed CoreGraphics image-local patch and a fully specified lifecycle projection rather than a naive _CGSMainDisplayID interposer?")
            line(fp, "multidisplay_note=The one-record proof does not authorize a count>1 production projection; any later design must project all relevant local entries coherently or stop.")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_projection_integration_seam_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No mouse/titlebar gesture was issued.")
            line(fp, "CoreGraphics and HIToolbox were read only.")
            line(fp, "No process-local mapping pointer was written.")
            line(fp, "No private CoreGraphics function was called.")
            line(fp, "No interposer was built or loaded.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")
            line(fp, "No shared memory, CoreGraphics, HIToolbox, WindowServer, Rosetta cache, dyld, or XNU state was modified.")
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)

    return 1 if issues else 0

if __name__ == "__main__":
    sys.exit(main())
