#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-projection-seam-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "targets": [
            "_initCGDisplayState",
            "_initCGDisplayMappings",
            "_bindDisplayMapping",
            "_CGSReleaseAllDisplays",
            "_CGSDisplayServerShutdown",
            "_updateAllDisplayInfoAsNeeded",
            "_CGSDisplayChangedSeed",
            "_CGSDisplayMappingChangedSeed",
            "_CGSDisplayNotifyProc",
            "__CGSDisplayInitialize",
            "_lookupMainDisplay",
        ],
        "edges": [
            ("_initCGDisplayMappings", "_initCGDisplayState"),
            ("_initCGDisplayMappings", "_bindDisplayMapping"),
            ("_initCGDisplayMappings", "_CGSDisplayChangedSeed"),
            ("_initCGDisplayMappings", "_CGSDisplayMappingChangedSeed"),
            ("_updateAllDisplayInfoAsNeeded", "_initCGDisplayMappings"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSReleaseAllDisplays"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSDisplayChangedSeed"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSDisplayMappingChangedSeed"),
            ("_CGSDisplayNotifyProc", "_updateAllDisplayInfoAsNeeded"),
            ("__CGSDisplayInitialize", "_initCGDisplayMappings"),
        ],
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "targets": [
            "_initDisplayState",
            "_initDisplayMappings",
            "_CGSReleaseAllDisplays",
            "_CGSDisplayServerShutdown",
            "_updateAllDisplayInfoAsNeeded",
            "_CGSDisplayChangedSeed",
            "_CGSDisplayMappingChangedSeed",
            "__CGSDisplayNotifyProc",
            "__CGSDisplayInitialize",
            "_lookupMainDisplay",
        ],
        "edges": [
            ("_initDisplayMappings", "_initDisplayState"),
            ("_initDisplayMappings", "_CGSDisplayChangedSeed"),
            ("_initDisplayMappings", "_CGSDisplayMappingChangedSeed"),
            ("_updateAllDisplayInfoAsNeeded", "_initDisplayMappings"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSReleaseAllDisplays"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSDisplayChangedSeed"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSDisplayMappingChangedSeed"),
            ("__CGSDisplayNotifyProc", "_updateAllDisplayInfoAsNeeded"),
            ("__CGSDisplayInitialize", "_initDisplayMappings"),
        ],
    },
}

BRANCH_OPS = set(["bl", "b", "bla", "bctrl", "blrl", "calll", "jmp"])

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
    caller_idxs = exact_indices(symbols, caller_name)
    callee_idxs = exact_indices(symbols, callee_name)
    if len(caller_idxs) != 1 or len(callee_idxs) != 1:
        return False
    target_addr = symbols[callee_idxs[0]][0]
    for row in groups.get(caller_idxs[0], []):
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
    addr = symbols[idx][0]
    selected = groups.get(idx, [])
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "instruction_lines=%d" % len(selected))
    line(fp, "-- full body --")
    for row in selected:
        line(fp, row[3])
    line(fp, "-- call/branch subset --")
    count = 0
    for row in selected:
        if row[1] in BRANCH_OPS:
            line(fp, row[3])
            count += 1
    line(fp, "call_branch_count=%d" % count)

def emit_callers(fp, symbols, groups, target_name):
    idxs = exact_indices(symbols, target_name)
    line(fp)
    line(fp, "== Direct callers: %s ==" % target_name)
    if len(idxs) != 1:
        line(fp, "target_count=%d" % len(idxs))
        return
    target_addr = symbols[idxs[0]][0]
    hits = []
    for idx, selected in groups.items():
        if idx == idxs[0]:
            continue
        for row in selected:
            if branch_hits_target(row, target_name, target_addr):
                hits.append((symbols[idx][1], symbols[idx][0], row[0], row[3]))
    line(fp, "direct_caller_reference_count=%d" % len(hits))
    callers = []
    for caller, caller_addr, site, raw in hits:
        if caller not in callers:
            callers.append(caller)
        line(fp, "caller=%s@0x%x site=0x%x raw=%s" %
             (caller, caller_addr, site, raw))
    line(fp, "unique_caller_count=%d" % len(callers))
    line(fp, "unique_callers=%s" %
         (",".join(callers) if callers else "NONE"))

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-projection-seam.")

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
            line(fp, "== PPC Carbon GUI display-shmem projection-seam audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % (mode or "unsupported"))
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "prior_consumer_topology=V2_PASS")
            line(fp, "prior_live_layout_mismatch=CAUSAL")
            line(fp, "server_owned_shared_record_write_authorized=NO")
            line(fp, "process_local_projection_implementation_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
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
                        exact = actual == cfg["slice_sha256"]
                        line(fp, "slice_sha256=%s" % actual)
                        line(fp, "slice_exact=%s" % ("YES" if exact else "NO"))
                        if not exact:
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
                        line(fp, "== Required lifecycle edges ==")
                        for caller, callee in cfg["edges"]:
                            present = has_edge(symbols, groups, caller, callee)
                            line(fp, "edge=%s->%s present=%s" %
                                 (caller, callee, "YES" if present else "NO"))
                            if not present:
                                issues.append("missing lifecycle edge: %s -> %s" %
                                              (caller, callee))

                        for name in cfg["targets"]:
                            emit_target(fp, symbols, groups, name)

                        for name in (
                            "_initCGDisplayState" if mode == "snow" else "_initDisplayState",
                            "_initCGDisplayMappings" if mode == "snow" else "_initDisplayMappings",
                            "_CGSReleaseAllDisplays",
                            "_updateAllDisplayInfoAsNeeded",
                            "_CGSDisplayNotifyProc" if mode == "snow" else "__CGSDisplayNotifyProc",
                        ):
                            emit_callers(fp, symbols, groups, name)

            line(fp)
            line(fp, "== Projection-seam questions ==")
            line(fp, "question_1=Does the release-local state initializer own the only non-shutdown installation of the two mode-1 display-source pointers?")
            line(fp, "question_2=Does the Snow mapping initializer derive every local mapping entry from the source slot before calling _bindDisplayMapping?")
            line(fp, "question_3=Exactly what does _CGSReleaseAllDisplays free, clear, or leave mapped when the mapping seed changes?")
            line(fp, "question_4=Does the display notification callback synchronously enter _updateAllDisplayInfoAsNeeded before later display queries observe changed seeds?")
            line(fp, "question_5=What release-local initialization path registers the notification callback, and is there a narrow observable hook for refreshing a private projection?")
            line(fp, "question_6=Which source-record offsets are consumed by _bindDisplayMapping before a projected record could safely participate in normal mapping rebuild?")
            line(fp, "question_7=Can a proof-only experiment redirect only a process-local local-mapping record pointer, restore it immediately, and avoid rebuilding mappings or touching server-owned bytes?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_projection_seam_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No display/CGS/WindowServer request was issued.")
            line(fp, "CoreGraphics was read only.")
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
