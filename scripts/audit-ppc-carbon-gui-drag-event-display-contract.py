#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-drag-event-display-contract-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

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

CORE_EXACT = [
    "_CGSGetDisplayBounds",
    "_CGDisplayBounds",
    "_CGMainDisplayID",
    "_CGGetActiveDisplayList",
    "_CGSGetUnflippedEventLocation",
    "_CGSGetUnflippedWindowEventLocation",
    "_CGSGetWindowMouseLocation",
    "_CGSGetNextEventRecord",
    "_CGSGetNextEventRecordInternal",
    "_CGSGetNextEventRecordFromMessage",
    "_CGSExtractEventRecordsFromMessage",
    "_CGSEventRecordLength",
    "_CGSTranslateEventRecordToEvent",
    "_CGSTranslateEventToEventRecord",
    "_CGSDecodeEventRecord",
    "_CGSEncodeEventRecord",
]

CORE_PATTERNS = [
    ("display_bounds", re.compile(r"(CGSGetDisplayBounds|CGDisplayBounds|CGMainDisplayID|CGGetActiveDisplayList)$", re.I)),
    ("unflipped_event_location", re.compile(r"CGSGetUnflippedEventLocation$", re.I)),
    ("unflipped_window_event_location", re.compile(r"CGSGetUnflippedWindowEventLocation$", re.I)),
    ("window_mouse_location", re.compile(r"CGSGetWindowMouseLocation$", re.I)),
    ("next_event", re.compile(r"CGSGetNextEventRecord|CGSExtractEventRecordsFromMessage", re.I)),
    ("event_record_translation", re.compile(r"CGS.*(TranslateEvent|DecodeEventRecord|EncodeEventRecord|EventRecordLength)", re.I)),
    ("display_lookup", re.compile(r"(lookupMasterDisplay|updateAllDisplayInfoAsNeeded|lockDisplay|unlockDisplay)", re.I)),
]

HIT_PATTERNS = [
    ("track_mouse", re.compile(r"TrackMouseLocation", re.I)),
    ("window_tracker", re.compile(r"TWindowTracker.*(TrackWindow|OnMouseMoved|RelocateWindowImage)", re.I)),
    ("drag_tracker", re.compile(r"TDragTracker.*OnMouseMoved", re.I)),
    ("point_bridge", re.compile(r"HIPoint(To|From)QDPoint", re.I)),
    ("drag_window", re.compile(r"(^|_)DragWindow$", re.I)),
    ("display_api_users", re.compile(r"(DisplayBounds|MainDisplay|ActiveDisplay|DisplayID)", re.I)),
]

FOCUS_STRING_RE = re.compile(
    r"(CGSGetDisplayBounds|Invalid display|GetUnflippedEventLocation|"
    r"GetNextEventRecord|EventRecord|TrackMouseLocation|HIPointToQDPoint)",
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

def find_exact(symbols, name):
    return [i for i, item in enumerate(symbols) if item[1] == name]

def matching(symbols, pattern):
    return [i for i, item in enumerate(symbols) if pattern.search(item[1])]

def emit_function(fp, symbols, groups, idx, label):
    addr, name, raw = symbols[idx]
    selected = groups.get(idx, [])
    line(fp)
    line(fp, "== %s: %s ==" % (label, name))
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "symbol_record=%s" % raw)
    line(fp, "instruction_lines=%d" % len(selected))
    for a, r in selected:
        line(fp, r)

def emit_callers(fp, symbols, groups, idx):
    addr, name, raw = symbols[idx]
    forms = ["0x%x" % addr, "0x%08x" % addr]
    name_lower = name.lower()
    hits = []
    for ci, selected in groups.items():
        if ci == idx:
            continue
        for a, r in selected:
            low = r.lower()
            if name_lower in low or any(f.lower() in low for f in forms):
                hits.append((ci, a, r))
    line(fp, "direct_reference_count=%d" % len(hits))
    for ci, a, r in hits[:240]:
        line(fp, "caller=%s@0x%x call_site=0x%x raw=%s" %
             (symbols[ci][1], symbols[ci][0], a, r))

def emit_focused_symbols(fp, title, symbols, patterns):
    line(fp)
    line(fp, "== %s focused symbol inventory ==" % title)
    seen = set()
    for label, pattern in patterns:
        idxs = matching(symbols, pattern)
        line(fp, "%s_symbol_count=%d" % (label, len(idxs)))
        for idx in idxs:
            if idx in seen:
                continue
            seen.add(idx)
            line(fp, "%s@0x%x" % (symbols[idx][1], symbols[idx][0]))

def emit_strings(fp, binary):
    rc, out = run(["/usr/bin/strings", "-a", binary])
    line(fp)
    line(fp, "== Focused strings ==")
    if rc != 0:
        line(fp, "strings_failed")
        return
    hits = [x for x in out.splitlines() if FOCUS_STRING_RE.search(x)]
    line(fp, "focused_string_count=%d" % len(hits))
    for x in hits[:800]:
        line(fp, x)

def analyze_image(fp, label, path, arch, expected_slice, patterns, exact_names, tempdir, issues):
    line(fp)
    line(fp, "== %s ==" % label)
    line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        line(fp, "state=MISSING")
        issues.append("%s missing" % label)
        return None, None

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
        return None, None

    slice_hash = sha256(dst)
    line(fp, "slice_sha256=%s" % slice_hash)
    line(fp, "slice_exact=%s" % ("YES" if slice_hash == expected_slice else "NO"))
    if slice_hash != expected_slice:
        issues.append("%s slice SHA-256 mismatch" % label)

    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        line(fp, "nm_failed")
        line(fp, nm_out.rstrip())
        issues.append("%s nm failed" % label)
        return None, None
    symbols = parse_symbols(nm_out)
    line(fp, "parsed_text_symbols=%d" % len(symbols))

    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        line(fp, "otool_disassembly_failed")
        line(fp, dis_out.rstrip())
        issues.append("%s otool failed" % label)
        return symbols, None
    rows = parse_rows(dis_out)
    groups = group_rows(rows, symbols)
    line(fp, "parsed_instruction_lines=%d" % len(rows))

    emit_focused_symbols(fp, label, symbols, patterns)
    emit_strings(fp, dst)

    emitted = set()
    for name in exact_names:
        idxs = find_exact(symbols, name)
        line(fp)
        line(fp, "exact_target=%s count=%d" % (name, len(idxs)))
        for idx in idxs:
            if idx in emitted:
                continue
            emitted.add(idx)
            emit_function(fp, symbols, groups, idx, label + " target")
            emit_callers(fp, symbols, groups, idx)

    # Emit all pattern matches that exact-name selection did not already cover.
    for plabel, pattern in patterns:
        for idx in matching(symbols, pattern):
            if idx in emitted:
                continue
            emitted.add(idx)
            emit_function(fp, symbols, groups, idx, label + " family " + plabel)
            emit_callers(fp, symbols, groups, idx)

    return symbols, groups

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-drag-event-display.")

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
            line(fp, "== PPC Carbon GUI drag event/display contract audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "live_snow_move_entry_interpose_count=0")
            line(fp, "live_lion_move_entry_interpose_count=0")
            line(fp, "live_snow_display0_diagnostic_count=0")
            line(fp, "live_lion_display0_diagnostic_count=8")
            line(fp, "live_lion_first_titlebar_mouse_down=302,109,inDrag")
            line(fp, "live_lion_first_move_delta=-302,-98")
            line(fp, "live_lion_observer_first_bad_origin=-182,17177")
            line(fp, "move_payload_rewrite_authorized=NO")
            line(fp, "private_HIToolbox_patch_authorized=NO")
            line(fp, "event_payload_rewrite_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
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
                    line(fp, "cache_map_contains_hitoolbox=%s" %
                         ("YES" if HITOOLBOX in data else "NO"))
                except IOError as e:
                    line(fp, "rosetta_cache_map_read_error=%s" % e)
            else:
                line(fp, "rosetta_cache_map=MISSING")

            if arch is not None:
                core_symbols, core_groups = analyze_image(
                    fp, "CoreGraphics", COREGRAPHICS, arch,
                    EXPECTED[mode]["coregraphics_slice"],
                    CORE_PATTERNS, CORE_EXACT, tempdir, issues)

                hit_exact = []
                hit_symbols, hit_groups = analyze_image(
                    fp, "HIToolbox", HITOOLBOX, arch,
                    EXPECTED[mode]["hitoolbox_slice"],
                    HIT_PATTERNS, hit_exact, tempdir, issues)

                if core_symbols is not None:
                    required = [
                        "_CGSGetDisplayBounds",
                        "_CGSGetUnflippedEventLocation",
                        "_CGSGetNextEventRecord",
                    ]
                    for name in required:
                        if not find_exact(core_symbols, name):
                            issues.append("required CoreGraphics target missing: %s" % name)

                    translate_count = 0
                    for name in ("_CGSTranslateEventRecordToEvent",
                                 "_CGSDecodeEventRecord",
                                 "_CGSGetNextEventRecordInternal"):
                        translate_count += len(find_exact(core_symbols, name))
                    if translate_count == 0:
                        issues.append("event-record translation family missing")

                if hit_symbols is not None:
                    track_count = 0
                    for label, pattern in HIT_PATTERNS:
                        if label in ("track_mouse", "window_tracker", "drag_tracker", "point_bridge"):
                            track_count += len(matching(hit_symbols, pattern))
                    if track_count == 0:
                        issues.append("HIToolbox drag/mouse family missing")

            line(fp)
            line(fp, "== Questions to resolve by Snow/Lion comparison ==")
            line(fp, "question_1=Which event-record field supplies the display ID consumed by CGSGetUnflippedEventLocation?")
            line(fp, "question_2=Do Snow PPC and Lion native use the same field offsets for mouse coordinates and display identity?")
            line(fp, "question_3=What exact local path produces CGSGetDisplayBounds(display 0), and what output/status survives that failure?")
            line(fp, "question_4=Does TrackMouseLocation/HIPointToQDPoint consume a point whose source field layout changed between releases?")
            line(fp, "question_5=Is the next narrow boundary event-record projection, display identity, or neither?")
            line(fp, "note_721f=Do not infer CGSGetDisplayBounds from 0x721f/0x7283; prior static ownership maps that pair to CGSGetSystemWindow.")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "drag_event_display_contract_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No mouse/titlebar gesture was issued.")
            line(fp, "No CGS, WindowServer, Mach, bootstrap, or notification request was issued.")
            line(fp, "CoreGraphics and HIToolbox were read only.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")
            line(fp, "No CoreGraphics, HIToolbox, Rosetta cache, WindowServer, dyld, or XNU state was modified.")
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)

    return 1 if issues else 0

if __name__ == "__main__":
    sys.exit(main())
