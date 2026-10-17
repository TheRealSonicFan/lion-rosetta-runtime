#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import deque

ANALYZER_VERSION = "2"
AUDIT_CONTRACT = "carbon-gui-dragwindow-main-display-boundary-v1"

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

HIT_FOCUS = [
    ("DragWindow", re.compile(r"^_DragWindow$")),
    ("WindowTrackerTrackWindow", re.compile(r"TWindowTracker11TrackWindow")),
    ("WindowTrackerOnMouseMoved", re.compile(r"TWindowTracker12OnMouseMoved")),
    ("DragTrackerOnMouseMoved", re.compile(r"TDragTracker12OnMouseMoved")),
    ("WindowTrackerCtor", re.compile(r"TWindowTrackerC[12]")),
    ("DragTrackerCtor", re.compile(r"TDragTrackerC[12]")),
]

CORE_FOCUS = [
    "_CGMainDisplayID",
    "_CGSMainDisplayID",
    "_CGDisplayBounds",
    "_CGSGetDisplayBounds",
    "_CGSGetUnflippedEventLocation",
    "_CGEventGetUnflippedLocation",
]

INTERESTING_IMPORTS = [
    "_CGMainDisplayID",
    "_CGDisplayBounds",
    "_CGSGetCurrentCursorLocation",
    "_CGSGetWindowBounds",
    "_CGGetActiveDisplayList",
    "_CGEventCreateNextEvent",
    "_CGEventGetEventRecord",
]

STUB_RE = re.compile(r"symbol stub for:\s*([^\s]+)", re.I)
CALL_RE = re.compile(r"\b(bl|bctrl|calll|jmp|b)\b(?:\s+([^\s;]+))?", re.I)

def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out

def line(fp, value=""):
    fp.write(value)
    fp.write("\n")

def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]

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
    result = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex(parts[0])
        if addr is not None:
            result.append((addr, raw))
    return result

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

def undefined_imports(path):
    rc, out = run(["/usr/bin/nm", "-u", path])
    result = set()
    if rc != 0:
        return result
    for raw in out.splitlines():
        parts = raw.split()
        if parts:
            result.add(parts[-1])
    return result

def analyze_image(fp, label, path, arch, expected_hash, tempdir, issues):
    line(fp)
    line(fp, "== %s ==" % label)
    line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        line(fp, "state=MISSING")
        issues.append("%s missing" % label)
        return None

    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    line(fp, out.rstrip())

    dst = os.path.join(tempdir, label + "." + arch)
    ok, out = thin(path, arch, dst)
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        issues.append("%s required slice missing" % label)
        return None

    slice_hash = sha256(dst)
    exact = slice_hash == expected_hash
    line(fp, "slice_sha256=%s" % slice_hash)
    line(fp, "slice_exact=%s" % ("YES" if exact else "NO"))
    if not exact:
        issues.append("%s slice SHA-256 mismatch" % label)

    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        issues.append("%s nm failed" % label)
        return None
    symbols = parse_symbols(nm_out)
    line(fp, "parsed_text_symbols=%d" % len(symbols))

    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        issues.append("%s otool failed" % label)
        return None
    rows = parse_rows(dis_out)
    groups = group_rows(rows, symbols)
    line(fp, "parsed_instruction_lines=%d" % len(rows))

    return {
        "path": dst,
        "symbols": symbols,
        "groups": groups,
        "imports": undefined_imports(dst),
    }

def indexes_by_name(image):
    result = {}
    for idx, item in enumerate(image["symbols"]):
        result.setdefault(item[1], []).append(idx)
    return result

def index_by_addr(image):
    result = {}
    for idx, item in enumerate(image["symbols"]):
        result[item[0]] = idx
    return result

def parse_call(raw, image, caller_idx, names, by_addr):
    stub = STUB_RE.search(raw)
    if stub:
        return ("external", stub.group(1), None)

    parts = raw.split(None, 1)
    if len(parts) < 2:
        return None
    m = CALL_RE.search(parts[1])
    if not m:
        return None

    op = m.group(1).lower()
    target = m.group(2)
    if op == "bctrl":
        return ("indirect", None, None)
    if target is None:
        return None
    if target.startswith("*"):
        return ("indirect", target, None)

    if target in image["imports"]:
        return ("external", target, None)
    if target.startswith("_") and target in names:
        idx = names[target][0]
        if idx != caller_idx:
            return ("internal", target, idx)
        return None

    addr = parse_hex(target)
    if addr is not None:
        idx = by_addr.get(addr)
        if idx is not None and idx != caller_idx:
            return ("internal", image["symbols"][idx][1], idx)
    return None

def calls_for_function(image, idx):
    if "_name_index" not in image:
        image["_name_index"] = indexes_by_name(image)
    if "_addr_index" not in image:
        image["_addr_index"] = index_by_addr(image)
    cache = image.setdefault("_call_cache", {})
    if idx in cache:
        return cache[idx]

    names = image["_name_index"]
    by_addr = image["_addr_index"]
    result = []
    for addr, raw in image["groups"].get(idx, []):
        parsed = parse_call(raw, image, idx, names, by_addr)
        if parsed is not None:
            result.append((addr, raw, parsed))
    cache[idx] = result
    return result

def build_internal_graph(image):
    if "_internal_graph" in image and "_external_graph" in image:
        return image["_internal_graph"], image["_external_graph"]

    graph = {}
    external = {}
    for idx in image["groups"]:
        graph[idx] = []
        external[idx] = []
        for addr, raw, parsed in calls_for_function(image, idx):
            kind, name, target_idx = parsed
            if kind == "internal":
                graph[idx].append((target_idx, addr, raw))
            elif kind == "external":
                external[idx].append((name, addr, raw))

    image["_internal_graph"] = graph
    image["_external_graph"] = external
    return graph, external

def shortest_path_to_import(image, root_idx, import_name):
    graph, external = build_internal_graph(image)
    queue = deque([root_idx])
    predecessor = {root_idx: None}
    depth = {root_idx: 0}

    while queue:
        idx = queue.popleft()
        for name, addr, raw in external.get(idx, []):
            if name == import_name:
                path = []
                cur = idx
                while cur is not None:
                    path.append(cur)
                    cur = predecessor[cur]
                path.reverse()
                return (path, idx, addr, raw)

        if depth[idx] >= 31:
            continue

        for target_idx, addr, raw in graph.get(idx, []):
            if target_idx not in predecessor:
                predecessor[target_idx] = idx
                depth[target_idx] = depth[idx] + 1
                queue.append(target_idx)
    return None

def dump_function(fp, image, label, idx):
    sym = image["symbols"][idx]
    line(fp)
    line(fp, "== %s: %s ==" % (label, sym[1]))
    line(fp, "symbol_address=0x%x" % sym[0])
    line(fp, "symbol_record=%s" % sym[2])
    rows = image["groups"].get(idx, [])
    line(fp, "instruction_lines=%d" % len(rows))
    for addr, raw in rows:
        line(fp, raw)
    calls = calls_for_function(image, idx)
    line(fp, "parsed_call_count=%d" % len(calls))
    for addr, raw, parsed in calls:
        kind, name, target_idx = parsed
        if kind == "internal":
            target = image["symbols"][target_idx][1]
        else:
            target = name if name is not None else "INDIRECT"
        line(fp, "call kind=%s site=0x%x target=%s raw=%s" %
             (kind, addr, target, raw))

def find_focus(image, pattern):
    result = []
    for idx, item in enumerate(image["symbols"]):
        if pattern.search(item[1]):
            result.append(idx)
    return result

def direct_import_present(image, idx, name):
    for addr, raw, parsed in calls_for_function(image, idx):
        if parsed[0] == "external" and parsed[1] == name:
            return True
    return False

def internal_edge_present(image, source_name, target_name):
    names = indexes_by_name(image)
    if source_name not in names or target_name not in names:
        return False
    target_set = set(names[target_name])
    for source_idx in names[source_name]:
        for addr, raw, parsed in calls_for_function(image, source_idx):
            if parsed[0] == "internal" and parsed[2] in target_set:
                return True
    return False

def format_path(image, path):
    return " -> ".join([image["symbols"][idx][1] for idx in path])

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-dragwindow-main-display.")

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
            line(fp, "== PPC Carbon GUI DragWindow/main-display boundary audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "prior_import_closure=PASS")
            line(fp, "live_adapter_authorized=NO")
            line(fp, "coregraphics_text_patch_authorized=NO")
            line(fp, "persistent_projection_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            if arch is not None:
                core = analyze_image(
                    fp, "CoreGraphics", COREGRAPHICS, arch,
                    EXPECTED[mode]["coregraphics_slice"], tempdir, issues)
                hit = analyze_image(
                    fp, "HIToolbox", HITOOLBOX, arch,
                    EXPECTED[mode]["hitoolbox_slice"], tempdir, issues)

                if core is not None and hit is not None:
                    hit_focus = {}
                    line(fp)
                    line(fp, "== HIToolbox focus symbol inventory ==")
                    for label, pattern in HIT_FOCUS:
                        matches = find_focus(hit, pattern)
                        hit_focus[label] = matches
                        line(fp, "focus=%s count=%d" % (label, len(matches)))
                        for idx in matches:
                            line(fp, "focus_symbol=%s@0x%x" %
                                 (hit["symbols"][idx][1], hit["symbols"][idx][0]))

                    drag_matches = hit_focus.get("DragWindow", [])
                    if len(drag_matches) != 1:
                        issues.append("expected exactly one _DragWindow")
                    else:
                        drag_idx = drag_matches[0]
                        dump_function(fp, hit, "HIToolbox focus", drag_idx)

                        line(fp)
                        line(fp, "== DragWindow direct imported-boundary checks ==")
                        for name in INTERESTING_IMPORTS:
                            present = direct_import_present(hit, drag_idx, name)
                            line(fp, "dragwindow_direct_import=%s present=%s" %
                                 (name, "YES" if present else "NO"))

                        line(fp)
                        line(fp, "== DragWindow shortest direct-call paths to selected CoreGraphics imports ==")
                        line(fp, "callgraph_cache=building_once")
                        fp.flush()
                        sys.stderr.write("building HIToolbox direct-call graph once...\n")
                        sys.stderr.flush()
                        build_internal_graph(hit)
                        line(fp, "callgraph_cache=READY")
                        fp.flush()
                        sys.stderr.write("HIToolbox direct-call graph ready; resolving selected paths...\n")
                        sys.stderr.flush()
                        for name in INTERESTING_IMPORTS:
                            found = shortest_path_to_import(hit, drag_idx, name)
                            if found is None:
                                line(fp, "path_to_import=%s present=NO" % name)
                            else:
                                path, caller_idx, addr, raw = found
                                line(fp, "path_to_import=%s present=YES depth=%d path=%s" %
                                     (name, len(path) - 1, format_path(hit, path)))
                                line(fp, "path_terminal_call_site=0x%x caller=%s raw=%s" %
                                     (addr, hit["symbols"][caller_idx][1], raw))

                    for label in ["WindowTrackerTrackWindow",
                                  "WindowTrackerOnMouseMoved",
                                  "DragTrackerOnMouseMoved"]:
                        for idx in hit_focus.get(label, []):
                            dump_function(fp, hit, "HIToolbox focus", idx)

                    core_names = indexes_by_name(core)
                    line(fp)
                    line(fp, "== CoreGraphics focus symbol inventory ==")
                    for name in CORE_FOCUS:
                        matches = core_names.get(name, [])
                        line(fp, "core_focus=%s count=%d" % (name, len(matches)))
                        for idx in matches:
                            line(fp, "core_focus_symbol=%s@0x%x" %
                                 (core["symbols"][idx][1], core["symbols"][idx][0]))
                            dump_function(fp, core, "CoreGraphics focus", idx)

                    line(fp)
                    line(fp, "== CoreGraphics edge checks ==")
                    checks = [
                        ("_CGMainDisplayID", "_CGSMainDisplayID"),
                        ("_CGDisplayBounds", "_CGSGetDisplayBounds"),
                        ("_CGSGetUnflippedEventLocation", "_CGSMainDisplayID"),
                        ("_CGSGetUnflippedEventLocation", "_CGSGetDisplayBounds"),
                        ("_CGEventGetUnflippedLocation", "_CGSGetUnflippedEventLocation"),
                    ]
                    for source, target in checks:
                        present = internal_edge_present(core, source, target)
                        line(fp, "core_edge=%s->%s present=%s binding=image-local" %
                             (source, target, "YES" if present else "NO"))

                    line(fp)
                    line(fp, "== Interpretation markers ==")
                    if len(drag_matches) == 1:
                        line(fp, "snow_expected_direct_CGMainDisplayID=%s" %
                             ("YES" if direct_import_present(hit, drag_matches[0],
                                                            "_CGMainDisplayID") else "NO"))
                    line(fp, "event_unflip_private_main_edge=%s" %
                         ("YES" if internal_edge_present(core,
                                                        "_CGSGetUnflippedEventLocation",
                                                        "_CGSMainDisplayID") else "NO"))
                    line(fp, "event_unflip_private_bounds_edge=%s" %
                         ("YES" if internal_edge_present(core,
                                                        "_CGSGetUnflippedEventLocation",
                                                        "_CGSGetDisplayBounds") else "NO"))
                    line(fp, "public_main_to_private_main_edge=%s" %
                         ("YES" if internal_edge_present(core,
                                                        "_CGMainDisplayID",
                                                        "_CGSMainDisplayID") else "NO"))

            line(fp)
            line(fp, "== Decision questions ==")
            line(fp, "question_1=What does _DragWindow do with its imported _CGMainDisplayID result, and does that call occur before tracker construction/TrackWindow?")
            line(fp, "question_2=Does Lion retain an equivalent direct or helper-mediated public main-display call on the DragWindow path?")
            line(fp, "question_3=Does public _CGMainDisplayID enter the same private _CGSMainDisplayID path used by the zero-cache event-unflip fallback, or a separate path?")
            line(fp, "question_4=Can interposing only the HIToolbox public _CGMainDisplayID call possibly affect the later image-local _CGSGetUnflippedEventLocation->_CGSMainDisplayID->_CGSGetDisplayBounds sequence?")
            line(fp, "question_5=If that imported call is only setup/constraint logic, is the interposable-seam branch closed for the actual failing fallback, leaving image-local CoreGraphics repair versus a fully specified lifecycle projection?")
            line(fp, "question_6=If a helper path is still relevant, what exact lifetime and locking scope would be required to avoid persistent partial projection?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "dragwindow_main_display_boundary_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No mouse/titlebar gesture was issued.")
            line(fp, "CoreGraphics and HIToolbox were read only.")
            line(fp, "No interposer was built or loaded.")
            line(fp, "No process-local mapping pointer was written.")
            line(fp, "No private CoreGraphics function was called.")
            line(fp, "Temporary architecture slices were removed on exit.")
            line(fp, "No shared memory, CoreGraphics, HIToolbox, WindowServer, Rosetta cache, dyld, or XNU state was modified.")
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)

    return 1 if issues else 0

if __name__ == "__main__":
    sys.exit(main())
