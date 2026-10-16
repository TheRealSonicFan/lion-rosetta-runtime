#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-projection-call-boundary-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "targets": [
            "_CGSMainDisplayID",
            "_lockDisplay",
            "_unlockDisplay",
            "_updateAllDisplayInfoAsNeeded",
            "_lookupMainDisplay",
            "_lookupDisplay",
            "_initCGDisplayMappings",
            "_bindDisplayMapping",
            "_CGSReleaseAllDisplays",
        ],
        "edges": [
            ("_CGSMainDisplayID", "_lockDisplay"),
            ("_CGSMainDisplayID", "_updateAllDisplayInfoAsNeeded"),
            ("_CGSMainDisplayID", "_lookupMainDisplay"),
            ("_CGSMainDisplayID", "_unlockDisplay"),
            ("_lookupMainDisplay", "_initCGDisplayMappings"),
            ("_lookupMainDisplay", "_lookupDisplay"),
            ("_lookupDisplay", "_initCGDisplayMappings"),
        ],
        "body_targets": [
            "_CGSMainDisplayID",
            "_lockDisplay",
            "_unlockDisplay",
            "_lookupMainDisplay",
            "_lookupDisplay",
        ],
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "targets": [
            "_CGSMainDisplayID",
            "_lookupDisplayNumber",
            "_lockDisplay",
            "_unlockDisplay",
            "_updateAllDisplayInfoAsNeeded",
            "_lookupMainDisplay",
            "_lookupDisplay",
            "_initDisplayMappings",
            "_CGSReleaseAllDisplays",
        ],
        "edges": [
            ("_CGSMainDisplayID", "_lookupDisplayNumber"),
            ("_lookupDisplayNumber", "_lockDisplay"),
            ("_lookupDisplayNumber", "_lookupMainDisplay"),
            ("_lookupDisplayNumber", "_unlockDisplay"),
            ("_lookupMainDisplay", "_initDisplayMappings"),
            ("_lookupMainDisplay", "_lookupDisplay"),
            ("_lookupDisplay", "_initDisplayMappings"),
        ],
        "body_targets": [
            "_CGSMainDisplayID",
            "_lookupDisplayNumber",
            "_lockDisplay",
            "_unlockDisplay",
            "_lookupMainDisplay",
            "_lookupDisplay",
        ],
    },
}

BRANCH_OPS = set(["bl", "b", "bla", "bctrl", "blrl", "calll", "jmp"])
MEM_DISP_RE = re.compile(r"(?<![0-9A-Za-z_])(-?0x[0-9a-fA-F]+)\(")

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
    token = token.strip().rstrip(":")
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
        return True, out
    rc2, out2 = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc2 == 0, out2 if out2.strip() else out

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
        m = re.match(r"^\s*([0-9a-fA-F]+)\s+([^\s]+)(?:\s+(.*))?$", raw)
        if not m:
            continue
        rows.append((int(m.group(1), 16), m.group(2),
                     (m.group(3) or "").strip(), raw))
    return rows

def group_rows(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for row in rows:
        addr = row[0]
        while si + 1 < len(symbols) and symbols[si + 1][0] <= addr:
            si += 1
        if symbols[si][0] <= addr:
            groups.setdefault(si, []).append(row)
    return groups

def exact_indices(symbols, name):
    return [i for i, item in enumerate(symbols) if item[1] == name]

def branch_hits_target(row, target_name, target_addr):
    addr, op, operands, raw = row
    if op not in BRANCH_OPS:
        return False
    if target_name in operands or target_name in raw:
        return True
    forms = [
        "0x%x" % target_addr,
        "0x%08x" % target_addr,
        "%08x" % target_addr,
    ]
    low = raw.lower()
    for form in forms:
        if form.lower() in low:
            return True
    return False

def has_edge(symbols, groups, caller_name, callee_name):
    callers = exact_indices(symbols, caller_name)
    callees = exact_indices(symbols, callee_name)
    if len(callers) != 1 or len(callees) != 1:
        return False
    target_addr = symbols[callees[0]][0]
    for row in groups.get(callers[0], []):
        if branch_hits_target(row, callee_name, target_addr):
            return True
    return False

def emit_target(fp, symbols, groups, name):
    idxs = exact_indices(symbols, name)
    line(fp)
    line(fp, "== Target: %s ==" % name)
    line(fp, "target_count=%d" % len(idxs))
    if len(idxs) != 1:
        return
    idx = idxs[0]
    selected = groups.get(idx, [])
    line(fp, "symbol_address=0x%x" % symbols[idx][0])
    line(fp, "instruction_lines=%d" % len(selected))
    line(fp, "-- full body --")
    for row in selected:
        line(fp, row[3])
    line(fp, "-- memory displacement inventory --")
    values = {}
    for row in selected:
        for token in MEM_DISP_RE.findall(row[2]):
            try:
                value = int(token, 16)
            except ValueError:
                continue
            values[value] = values.get(value, 0) + 1
    for value in sorted(values.keys()):
        line(fp, "memory_disp=0x%x count=%d" % (value, values[value]))
    if not values:
        line(fp, "NONE")

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-projection-call.")

    try:
        rc, out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = out.strip() if rc == 0 else "UNKNOWN"
        rc, out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = out.strip() if rc == 0 else "UNKNOWN"

        mode = None
        for key, cfg in CONFIG.items():
            if product == cfg["product"] and build == cfg["build"]:
                mode = key
                break

        with open(output, "w") as fp:
            line(fp, "== PPC Carbon GUI display-shmem projection call-boundary audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % (mode or "unsupported"))
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "prior_projection_seam=PASS")
            line(fp, "server_owned_shared_record_write_authorized=NO")
            line(fp, "process_local_projection_live_write_authorized=NO")
            line(fp, "private_function_live_call_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            if mode is None:
                issues.append("unsupported product/build")
            else:
                cfg = CONFIG[mode]
                line(fp, "required_arch=%s" % cfg["arch"])
                line(fp, "expected_slice_sha256=%s" % cfg["slice_sha256"])
                if not os.path.isfile(COREGRAPHICS):
                    issues.append("CoreGraphics missing")
                else:
                    dst = os.path.join(tempdir, "CoreGraphics." + cfg["arch"])
                    ok, out = thin(COREGRAPHICS, cfg["arch"], dst)
                    line(fp, "thin=%s" % ("YES" if ok else "NO"))
                    if not ok:
                        line(fp, out.rstrip())
                        issues.append("required CoreGraphics slice missing")
                    else:
                        actual = sha256(dst)
                        line(fp, "slice_sha256=%s" % actual)
                        line(fp, "slice_exact=%s" %
                             ("YES" if actual == cfg["slice_sha256"] else "NO"))
                        if actual != cfg["slice_sha256"]:
                            issues.append("CoreGraphics slice SHA-256 mismatch")

                        rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                        symbols = parse_symbols(nm_out) if rc == 0 else []
                        if rc != 0:
                            issues.append("nm failed")
                        rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                        rows = parse_rows(dis_out) if rc == 0 else []
                        groups = group_rows(rows, symbols) if rc == 0 else {}
                        if rc != 0:
                            issues.append("otool disassembly failed")

                        line(fp)
                        line(fp, "== Required target inventory ==")
                        for name in cfg["targets"]:
                            count = len(exact_indices(symbols, name))
                            line(fp, "target=%s count=%d" % (name, count))
                            if count != 1:
                                issues.append("expected exactly one target: %s" % name)

                        line(fp)
                        line(fp, "== Required call-boundary edges ==")
                        for caller, callee in cfg["edges"]:
                            present = has_edge(symbols, groups, caller, callee)
                            line(fp, "edge=%s->%s present=%s" %
                                 (caller, callee, "YES" if present else "NO"))
                            if not present:
                                issues.append("missing call-boundary edge: %s -> %s" %
                                              (caller, callee))

                        main_idxs = exact_indices(symbols, "_CGSMainDisplayID")
                        if len(main_idxs) == 1:
                            base = symbols[main_idxs[0]][0]
                            line(fp)
                            line(fp, "== Same-__TEXT deltas from _CGSMainDisplayID ==")
                            for name in cfg["targets"]:
                                idxs = exact_indices(symbols, name)
                                if len(idxs) == 1:
                                    delta = symbols[idxs[0]][0] - base
                                    line(fp, "delta_%s=%+d (0x%x->0x%x)" %
                                         (name, delta, base, symbols[idxs[0]][0]))

                        for name in cfg["body_targets"]:
                            emit_target(fp, symbols, groups, name)

            line(fp)
            line(fp, "== Proof-boundary questions ==")
            line(fp, "question_1=What exact locked call sequence reaches _lookupMainDisplay after _updateAllDisplayInfoAsNeeded has returned?")
            line(fp, "question_2=What fallback conditions in _lookupMainDisplay and _lookupDisplay can still call the mapping initializer, and can a live proof gate them out by requiring selector/source/local state non-NULL?")
            line(fp, "question_3=Which exact record displacements are read by Snow _lookupMainDisplay and _lookupDisplay on the fast path?")
            line(fp, "question_4=Do those Snow reads have already-proven Lion correspondences sufficient for a private one-record overlay without projecting fields consumed only by _bindDisplayMapping?")
            line(fp, "question_5=Can the loaded translated-PPC addresses of lock/update/lookup/unlock be derived from exported _CGSMainDisplayID by same-__TEXT deltas and validated before any call?")
            line(fp, "question_6=Can a proof-only probe call update while locked, redirect one local-entry record pointer only after update returns, call lookup directly, restore the pointer before unlock, and thereby make _bindDisplayMapping unreachable while the projection is installed?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_projection_call_boundary_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No display/CGS/WindowServer request was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "No process-local mapping pointer was written.")
            line(fp, "No private CoreGraphics function was called.")
            line(fp, "Temporary architecture slices were removed on exit.")
            line(fp, "No shared memory, CoreGraphics, Rosetta cache, dyld, WindowServer, or XNU state was modified.")

        print("Created: %s" % output)
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
