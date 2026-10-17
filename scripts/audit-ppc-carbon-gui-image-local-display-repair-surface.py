#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-image-local-display-repair-surface-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "targets": [
            "_CGSMainDisplayID",
            "_lookupMainDisplay",
            "_CGSGetDisplayBounds",
            "_lookupMasterDisplay",
            "_lookupDisplay",
            "_initCGDisplayMappings",
            "_bindDisplayMapping",
        ],
        "main_fields": [0x0f4, 0x0f8, 0x10c, 0x10d, 0x10e, 0x110, 0x111, 0x112, 0x113],
        "bounds_geometry_fields": [0x0d0, 0x0d4, 0x0d8, 0x0dc, 0x0e0, 0x0e4, 0x0e8, 0x0ec],
        "bounds_flag_field": 0x115,
        "source_stride": 0x150,
        "mapping_init": "_initCGDisplayMappings",
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "targets": [
            "_CGSMainDisplayID",
            "_lookupDisplayNumber",
            "_lookupMainDisplay",
            "_CGSGetDisplayBounds",
            "_lookupMasterDisplay",
            "_lookupDisplay",
            "_initDisplayMappings",
        ],
        "main_fields": [0x110, 0x114, 0x128, 0x129, 0x12a, 0x12c, 0x12d, 0x12e, 0x12f],
        "bounds_geometry_fields": [0x0dc, 0x0e0, 0x0e4, 0x0e8, 0x0ec, 0x0f0, 0x0f4, 0x0f8],
        "bounds_flag_field": 0x131,
        "source_stride": 0x17c,
        "mapping_init": "_initDisplayMappings",
    },
}

MAIN_PAIRS = [
    (0x0f4, 0x110),
    (0x0f8, 0x114),
    (0x10c, 0x128),
    (0x10d, 0x129),
    (0x10e, 0x12a),
    (0x110, 0x12c),
    (0x111, 0x12d),
    (0x112, 0x12e),
    (0x113, 0x12f),
]

BOUNDS_GEOMETRY_PAIRS = [
    (0x0d0, 0x0dc),
    (0x0d4, 0x0e0),
    (0x0d8, 0x0e4),
    (0x0dc, 0x0e8),
    (0x0e0, 0x0ec),
    (0x0e4, 0x0f0),
    (0x0e8, 0x0f4),
    (0x0ec, 0x0f8),
]

BOUNDS_FLAG_PAIR = (0x115, 0x131)

HEX_RE = re.compile(r"(?<![0-9A-Za-z_])0x([0-9a-fA-F]+)")
BRANCH_OPS = set(["bl", "b", "bla", "bctrl", "blrl", "calll", "jmp"])

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

def body_for(symbols, groups, name):
    idxs = exact_indices(symbols, name)
    if len(idxs) != 1:
        return []
    return groups.get(idxs[0], [])

def immediates(row):
    values = []
    for token in HEX_RE.findall(row[2]):
        try:
            values.append(int(token, 16))
        except ValueError:
            pass
    return values

def field_hits(rows, value):
    return [row for row in rows if value in immediates(row)]

def has_literal(rows, value):
    return len(field_hits(rows, value)) != 0

def emit_full_body(fp, symbols, groups, name):
    rows = body_for(symbols, groups, name)
    line(fp)
    line(fp, "== Target: %s ==" % name)
    line(fp, "target_count=%d" % len(exact_indices(symbols, name)))
    if len(exact_indices(symbols, name)) != 1:
        return
    idx = exact_indices(symbols, name)[0]
    line(fp, "symbol_address=0x%x" % symbols[idx][0])
    line(fp, "instruction_lines=%d" % len(rows))
    for row in rows:
        line(fp, row[3])

def emit_field_inventory(fp, name, rows, values):
    line(fp)
    line(fp, "== Field inventory: %s ==" % name)
    for value in values:
        hits = field_hits(rows, value)
        line(fp, "field=0x%x count=%d" % (value, len(hits)))
        for row in hits:
            line(fp, "field_hit=0x%x site=0x%x op=%s raw=%s" %
                 (value, row[0], row[1], row[3]))

def branch_hits_target(row, target_name, target_addr):
    if row[1] not in BRANCH_OPS:
        return False
    if target_name in row[2] or target_name in row[3]:
        return True
    low = row[3].lower()
    for form in ["0x%x" % target_addr, "0x%08x" % target_addr, "%08x" % target_addr]:
        if form.lower() in low:
            return True
    return False

def has_edge(symbols, groups, caller, callee):
    a = exact_indices(symbols, caller)
    b = exact_indices(symbols, callee)
    if len(a) != 1 or len(b) != 1:
        return False
    target = symbols[b[0]][0]
    for row in groups.get(a[0], []):
        if branch_hits_target(row, callee, target):
            return True
    return False

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-image-local-display-repair.")

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
            line(fp, "== PPC Carbon GUI image-local display repair surface audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % (mode or "unsupported"))
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "prior_dragwindow_main_display_boundary=PASS")
            line(fp, "prior_projection_proof=PASS")
            line(fp, "coregraphics_text_patch_authorized=NO")
            line(fp, "persistent_projection_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "xnu_change_authorized=NO")
            line(fp, "prior_source_record_stride_snow=0x150")
            line(fp, "prior_source_record_stride_lion=0x17c")
            line(fp, "prior_local_mapping_stride_snow=0x58")
            line(fp, "prior_local_mapping_stride_lion=0x68")

            if mode is None:
                issues.append("unsupported product/build")
            elif not os.path.isfile(COREGRAPHICS):
                issues.append("CoreGraphics missing")
            else:
                cfg = CONFIG[mode]
                line(fp, "required_arch=%s" % cfg["arch"])
                line(fp, "expected_slice_sha256=%s" % cfg["slice_sha256"])
                dst = os.path.join(tempdir, "CoreGraphics." + cfg["arch"])
                ok, thin_out = thin(COREGRAPHICS, cfg["arch"], dst)
                line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    line(fp, thin_out.rstrip())
                    issues.append("required CoreGraphics slice missing")
                else:
                    actual = sha256(dst)
                    line(fp, "slice_sha256=%s" % actual)
                    line(fp, "slice_exact=%s" % ("YES" if actual == cfg["slice_sha256"] else "NO"))
                    if actual != cfg["slice_sha256"]:
                        issues.append("CoreGraphics slice SHA-256 mismatch")

                    sys.stderr.write("disassembling pinned CoreGraphics slice...\n")
                    sys.stderr.flush()
                    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                    symbols = parse_symbols(nm_out) if rc == 0 else []
                    if rc != 0:
                        issues.append("nm failed")
                    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                    rows = parse_rows(dis_out) if rc == 0 else []
                    groups = group_rows(rows, symbols) if rc == 0 else {}
                    if rc != 0:
                        issues.append("otool disassembly failed")
                    sys.stderr.write("disassembly parsed; emitting focused repair surface...\n")
                    sys.stderr.flush()

                    line(fp)
                    line(fp, "== Required target inventory ==")
                    for name in cfg["targets"]:
                        count = len(exact_indices(symbols, name))
                        line(fp, "target=%s count=%d" % (name, count))
                        if count != 1:
                            issues.append("expected exactly one target: %s" % name)

                    lookup_main = body_for(symbols, groups, "_lookupMainDisplay")
                    bounds = body_for(symbols, groups, "_CGSGetDisplayBounds")
                    mapping = body_for(symbols, groups, cfg["mapping_init"])

                    emit_field_inventory(fp, "_lookupMainDisplay", lookup_main, cfg["main_fields"])
                    emit_field_inventory(fp, "_CGSGetDisplayBounds.geometry", bounds, cfg["bounds_geometry_fields"])
                    emit_field_inventory(fp, "_CGSGetDisplayBounds.flag", bounds, [cfg["bounds_flag_field"]])

                    main_complete = all(has_literal(lookup_main, v) for v in cfg["main_fields"])
                    bounds_geom_complete = all(has_literal(bounds, v) for v in cfg["bounds_geometry_fields"])
                    bounds_flag_complete = has_literal(bounds, cfg["bounds_flag_field"])
                    stride_present = has_literal(mapping, cfg["source_stride"])

                    line(fp)
                    line(fp, "== Repair-surface markers ==")
                    line(fp, "main_lookup_field_inventory_complete=%s" % ("YES" if main_complete else "NO"))
                    line(fp, "bounds_geometry_field_inventory_complete=%s" % ("YES" if bounds_geom_complete else "NO"))
                    line(fp, "bounds_flag_field_inventory_complete=%s" % ("YES" if bounds_flag_complete else "NO"))
                    line(fp, "mapping_initializer_source_stride=0x%x present=%s" %
                         (cfg["source_stride"], "YES" if stride_present else "NO"))
                    line(fp, "edge_CGSMainDisplayID_lookupMainDisplay=%s" %
                         ("YES" if has_edge(symbols, groups, "_CGSMainDisplayID", "_lookupMainDisplay") else "NO"))
                    line(fp, "edge_CGSGetDisplayBounds_lookupMasterDisplay=%s" %
                         ("YES" if has_edge(symbols, groups, "_CGSGetDisplayBounds", "_lookupMasterDisplay") else "NO"))

                    if not main_complete:
                        issues.append("main-display field inventory incomplete")
                    if not bounds_geom_complete:
                        issues.append("display-bounds geometry inventory incomplete")
                    if not bounds_flag_complete:
                        issues.append("display-bounds flag inventory incomplete")
                    if not stride_present:
                        issues.append("mapping initializer source stride literal not found")

                    line(fp)
                    line(fp, "== Cross-release correspondence under review ==")
                    for snow, lion in MAIN_PAIRS:
                        line(fp, "main_pair=0x%x->0x%x delta=0x%x" % (snow, lion, lion - snow))
                    for snow, lion in BOUNDS_GEOMETRY_PAIRS:
                        line(fp, "bounds_geometry_pair=0x%x->0x%x delta=0x%x" %
                             (snow, lion, lion - snow))
                    line(fp, "bounds_flag_pair=0x%x->0x%x delta=0x%x" %
                         (BOUNDS_FLAG_PAIR[0], BOUNDS_FLAG_PAIR[1],
                          BOUNDS_FLAG_PAIR[1] - BOUNDS_FLAG_PAIR[0]))
                    line(fp, "source_stride_pair=0x150->0x17c delta=0x2c")
                    line(fp, "field_only_lookup_patch_count_gt_1_safe=NO")
                    line(fp, "reason=Snow local record pointers are derived with 0x150 source stride while Lion records use 0x17c; changing only lookup field displacements cannot make later records address-correct.")
                    line(fp, "persistent_partial_projection_safe=NO")
                    line(fp, "reason=Snow bind/rebind consumes record fields outside the proven main-lookup projection window.")

                    for name in ["_lookupMainDisplay", "_lookupMasterDisplay",
                                 "_CGSGetDisplayBounds", "_lookupDisplay",
                                 cfg["mapping_init"]]:
                        emit_full_body(fp, symbols, groups, name)

            line(fp)
            line(fp, "== Decision questions ==")
            line(fp, "question_1=Does the main-display lookup require the established +0x1c field shift at all record reads on both releases?")
            line(fp, "question_2=Does _CGSGetDisplayBounds require a different geometry shift (+0x0c) while its selector/flag field remains shifted by +0x1c?")
            line(fp, "question_3=Does _lookupMasterDisplay introduce additional record-field dependencies before bounds can succeed with a corrected nonzero display ID?")
            line(fp, "question_4=Can any image-local repair be limited to _lookupMainDisplay and _CGSGetDisplayBounds, or must it also repair lookupMasterDisplay / lookupDisplay semantics?")
            line(fp, "question_5=Because Snow mapping entries are derived with source stride 0x150 while Lion records use 0x17c, can a field-only patch ever be count>1 safe without also changing mapping construction?")
            line(fp, "question_6=Given bind/rebind consumes fields outside the proven projection window, is a complete lifecycle projection materially larger and riskier than a narrowly scoped image-local compatibility routine that reads Lion layout directly?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "image_local_display_repair_surface_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No mouse/titlebar gesture was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "No CoreGraphics text or data was modified.")
            line(fp, "No process-local mapping pointer was written.")
            line(fp, "No private CoreGraphics function was called.")
            line(fp, "No display ID was substituted.")
            line(fp, "Temporary architecture slices were removed on exit.")
            line(fp, "No shared memory, WindowServer, Rosetta cache, dyld, or XNU state was modified.")

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
