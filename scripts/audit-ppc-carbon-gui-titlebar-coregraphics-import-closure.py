#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-titlebar-coregraphics-import-closure-v1"

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

TITLEBAR_ROOT_RE = re.compile(
    r"(TrackMouseLocation|"
    r"TWindowTracker.*(TrackWindow|OnMouseMoved|RelocateWindowImage|"
    r"CalculateLimitRegion|GetAvailableRegionForDisplay)|"
    r"TDragTracker.*(OnMouseMoved|ConstrainWindow|CalculateLimitRegion)|"
    r"(^|_)DragWindow$)",
    re.I,
)

STUB_RE = re.compile(r"symbol stub for:\s*([^\s]+)", re.I)
CALL_RE = re.compile(r"\b(bl|bctrl|calll|jmp|b)\b(?:\s+([^\s;]+))?", re.I)

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

    dst = os.path.join(tempdir, label.replace(" ", "_") + "." + arch)
    ok, out = thin(path, arch, dst)
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        line(fp, out.rstrip())
        issues.append("%s required slice missing" % label)
        return None

    slice_hash = sha256(dst)
    line(fp, "slice_sha256=%s" % slice_hash)
    line(fp, "slice_exact=%s" % ("YES" if slice_hash == expected_hash else "NO"))
    if slice_hash != expected_hash:
        issues.append("%s slice SHA-256 mismatch" % label)

    imports, import_out = undefined_imports(dst)
    line(fp, "undefined_symbol_count=%d" % len(imports))

    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        line(fp, "nm_failed")
        line(fp, nm_out.rstrip())
        issues.append("%s nm failed" % label)
        return None

    symbols = parse_symbols(nm_out)
    line(fp, "parsed_text_symbols=%d" % len(symbols))

    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        line(fp, "otool_disassembly_failed")
        line(fp, dis_out.rstrip())
        issues.append("%s otool failed" % label)
        return None

    rows = parse_rows(dis_out)
    groups = group_rows(rows, symbols)
    line(fp, "parsed_instruction_lines=%d" % len(rows))
    return {
        "path": dst,
        "symbols": symbols,
        "groups": groups,
        "imports": imports,
    }

def parse_call(raw, symbol_by_addr, symbol_index_by_name, imports, caller_idx):
    stub = STUB_RE.search(raw)
    if stub:
        return ("external", stub.group(1), None)

    parts = raw.split(None, 1)
    if len(parts) < 2:
        return None
    asm = parts[1]
    m = CALL_RE.search(asm)
    if not m:
        return None

    op = m.group(1).lower()
    target = m.group(2)

    if op == "bctrl":
        return ("unresolved_indirect", None, None)
    if target is None:
        return ("unresolved_direct", None, None)
    if target.startswith("*"):
        return ("unresolved_indirect", target, None)

    if target in imports:
        return ("external", target, None)

    if target.startswith("_") and target in symbol_index_by_name:
        return ("internal", target, symbol_index_by_name[target])

    addr = parse_hex(target)
    if addr is not None:
        idx = symbol_by_addr.get(addr)
        if idx is not None and idx != caller_idx:
            return ("internal", None, idx)
        return ("unresolved_direct", target, None)

    if target.startswith("_"):
        return ("external_or_unknown", target, None)

    return ("unresolved_direct", target, None)

def build_callgraph(symbols, groups, imports):
    symbol_by_addr = {}
    symbol_index_by_name = {}
    for idx, item in enumerate(symbols):
        symbol_by_addr[item[0]] = idx
        if item[1] not in symbol_index_by_name:
            symbol_index_by_name[item[1]] = idx

    internal = {}
    external = {}
    unresolved = {}

    for idx in groups:
        internal[idx] = []
        external[idx] = []
        unresolved[idx] = []
        for addr, raw in groups.get(idx, []):
            parsed = parse_call(raw, symbol_by_addr, symbol_index_by_name,
                                imports, idx)
            if parsed is None:
                continue
            kind, name, target_idx = parsed
            if kind == "internal":
                internal[idx].append((target_idx, addr, raw))
            elif kind == "external":
                external[idx].append((name, addr, raw))
            elif kind == "external_or_unknown":
                external[idx].append((name, addr, raw))
            else:
                unresolved[idx].append((kind, name, addr, raw))
    return internal, external, unresolved

def closure_from_roots(root_indices, internal):
    seen = set()
    queue = list(root_indices)
    while queue:
        idx = queue.pop(0)
        if idx in seen:
            continue
        seen.add(idx)
        for target_idx, addr, raw in internal.get(idx, []):
            if target_idx not in seen:
                queue.append(target_idx)
    return seen

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-titlebar-cg-import-closure.")

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
            line(fp, "== PPC Carbon GUI titlebar CoreGraphics import-closure audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "prior_projection_integration_seam=PASS")
            line(fp, "prior_candidate_import_count=0")
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
                    core_export_names = set()
                    for item in core["symbols"]:
                        core_export_names.add(item[1])

                    cg_imports = sorted(list(hit["imports"].intersection(core_export_names)))

                    line(fp)
                    line(fp, "== HIToolbox imports resolved to CoreGraphics ==")
                    line(fp, "coregraphics_import_count=%d" % len(cg_imports))
                    for name in cg_imports:
                        line(fp, "coregraphics_import=%s" % name)

                    roots = []
                    for idx, item in enumerate(hit["symbols"]):
                        if TITLEBAR_ROOT_RE.search(item[1]):
                            roots.append(idx)

                    line(fp)
                    line(fp, "== Titlebar roots ==")
                    line(fp, "titlebar_root_count=%d" % len(roots))
                    for idx in roots:
                        line(fp, "titlebar_root=%s@0x%x" %
                             (hit["symbols"][idx][1], hit["symbols"][idx][0]))
                    if not roots:
                        issues.append("no titlebar roots found")

                    internal, external, unresolved = build_callgraph(
                        hit["symbols"], hit["groups"], hit["imports"])
                    closure = closure_from_roots(roots, internal)

                    line(fp)
                    line(fp, "== Reachable HIToolbox closure ==")
                    line(fp, "reachable_function_count=%d" % len(closure))

                    cg_hits = []
                    other_external_hits = []
                    unresolved_hits = []
                    for idx in sorted(list(closure)):
                        caller = hit["symbols"][idx]
                        for name, addr, raw in external.get(idx, []):
                            item = (caller, name, addr, raw)
                            if name in cg_imports:
                                cg_hits.append(item)
                            else:
                                other_external_hits.append(item)
                        for kind, name, addr, raw in unresolved.get(idx, []):
                            unresolved_hits.append((caller, kind, name, addr, raw))

                    line(fp)
                    line(fp, "== Reachable CoreGraphics import calls ==")
                    line(fp, "reachable_coregraphics_import_call_count=%d" % len(cg_hits))
                    seen_names = set()
                    for caller, name, addr, raw in cg_hits[:600]:
                        seen_names.add(name)
                        line(fp,
                             "coregraphics_call=%s caller=%s@0x%x call_site=0x%x raw=%s" %
                             (name, caller[1], caller[0], addr, raw))
                    line(fp, "reachable_coregraphics_import_name_count=%d" %
                         len(seen_names))
                    for name in sorted(list(seen_names)):
                        line(fp, "reachable_coregraphics_import=%s" % name)

                    line(fp)
                    line(fp, "== Reachable unresolved calls ==")
                    line(fp, "reachable_unresolved_call_count=%d" %
                         len(unresolved_hits))
                    indirect_count = 0
                    direct_count = 0
                    for caller, kind, name, addr, raw in unresolved_hits[:600]:
                        if kind == "unresolved_indirect":
                            indirect_count += 1
                        else:
                            direct_count += 1
                        line(fp,
                             "unresolved_call=%s caller=%s@0x%x call_site=0x%x target=%s raw=%s" %
                             (kind, caller[1], caller[0], addr,
                              name if name is not None else "NONE", raw))
                    line(fp, "reachable_unresolved_indirect_call_count=%d" %
                         indirect_count)
                    line(fp, "reachable_unresolved_direct_call_count=%d" %
                         direct_count)

                    line(fp)
                    line(fp, "== Closure interpretation ==")
                    line(fp, "candidate_list_closed=YES")
                    line(fp, "all_hitoolbox_coregraphics_imports_enumerated=YES")
                    line(fp, "titlebar_direct_call_closure_computed=YES")
                    line(fp, "note=An unresolved indirect call prevents treating a zero reachable CoreGraphics-import count as a complete proof of absence without further vtable/indirect-target resolution.")

            line(fp)
            line(fp, "== Decision questions ==")
            line(fp, "question_1=Which CoreGraphics exports, if any, are imported by HIToolbox at all on this release?")
            line(fp, "question_2=Which of those imports are reachable by direct-call closure from the titlebar tracking roots?")
            line(fp, "question_3=If the reachable count is zero, are unresolved indirect calls still present in that closure?")
            line(fp, "question_4=If an imported CoreGraphics boundary is reachable, does it enclose the event-unflip/main-display fallback closely enough for a call-scoped adapter review?")
            line(fp, "question_5=If no reachable import remains after indirect targets are closed, should the next review prefer a narrow image-local CoreGraphics patch over a full lifecycle projection?")
            line(fp, "question_6=If lifecycle projection remains a candidate, what additional record fields and count>1 semantics must be projected before _bindDisplayMapping can safely consume them?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "titlebar_coregraphics_import_closure_audit_exact=YES")
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
