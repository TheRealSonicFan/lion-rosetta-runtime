#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-event-unflip-direct-source-helper-contract-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "mapping_init": "_initCGDisplayMappings",
        "notify": "_CGSDisplayNotifyProc",
        "source_stride": 0x150,
        "local_stride": 0x58,
        "event_cache_offset": 0xc6,
        "main_fields": [0x0f4, 0x0f8, 0x10c, 0x10d, 0x10e, 0x110, 0x111, 0x112, 0x113],
        "master_fields": [0x0f4, 0x0f8, 0x110, 0x111, 0x112],
        "bounds_fields": [0x0d0, 0x0d4, 0x0d8, 0x0dc, 0x0e0, 0x0e4, 0x0e8, 0x0ec, 0x115],
        "targets": [
            "_CGSGetUnflippedEventLocation",
            "_CGSMainDisplayID",
            "_CGSGetDisplayBounds",
            "_lookupMainDisplay",
            "_lookupMasterDisplay",
            "_lookupDisplay",
            "_initCGDisplayMappings",
            "_bindDisplayMapping",
            "_updateAllDisplayInfoAsNeeded",
            "_CGSReleaseAllDisplays",
            "_CGSDisplayNotifyProc",
            "_CGSDisplayServerShutdown",
            "_lockDisplay",
            "_unlockDisplay",
        ],
        "edges": [
            ("_CGSGetUnflippedEventLocation", "_CGSMainDisplayID"),
            ("_CGSGetUnflippedEventLocation", "_CGSGetDisplayBounds"),
            ("_CGSGetDisplayBounds", "_lookupMasterDisplay"),
            ("_lookupMasterDisplay", "_lookupDisplay"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSReleaseAllDisplays"),
            ("_CGSDisplayNotifyProc", "_updateAllDisplayInfoAsNeeded"),
        ],
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "mapping_init": "_initDisplayMappings",
        "notify": "__CGSDisplayNotifyProc",
        "source_stride": 0x17c,
        "local_stride": 0x68,
        "event_cache_offset": 0xbe,
        "main_fields": [0x110, 0x114, 0x128, 0x129, 0x12a, 0x12c, 0x12d, 0x12e, 0x12f],
        "master_fields": [0x114, 0x12e],
        "bounds_fields": [0x0dc, 0x0e0, 0x0e4, 0x0e8, 0x0ec, 0x0f0, 0x0f4, 0x0f8, 0x131],
        "targets": [
            "_CGSGetUnflippedEventLocation",
            "_CGSMainDisplayID",
            "_lookupDisplayNumber",
            "_CGSGetDisplayBounds",
            "_lookupMainDisplay",
            "_lookupMasterDisplay",
            "_lookupDisplay",
            "_initDisplayMappings",
            "_updateAllDisplayInfoAsNeeded",
            "_CGSReleaseAllDisplays",
            "__CGSDisplayNotifyProc",
            "_CGSDisplayServerShutdown",
            "_lockDisplay",
            "_unlockDisplay",
        ],
        "edges": [
            ("_CGSGetUnflippedEventLocation", "_CGSMainDisplayID"),
            ("_CGSGetUnflippedEventLocation", "_CGSGetDisplayBounds"),
            ("_CGSGetDisplayBounds", "_lookupMasterDisplay"),
            ("_lookupMasterDisplay", "_lookupDisplay"),
            ("_updateAllDisplayInfoAsNeeded", "_CGSReleaseAllDisplays"),
            ("__CGSDisplayNotifyProc", "_updateAllDisplayInfoAsNeeded"),
        ],
    },
}

BRANCH_OPS = set(["bl", "b", "bla", "bctrl", "blrl", "calll", "jmp"])
HEX_RE = re.compile(r"(?<![0-9A-Za-z_])0x([0-9a-fA-F]+)")

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
        if addr is not None:
            result.append((addr, parts[-1], raw))
    result.sort()
    return result

def parse_rows(text):
    rows = []
    for raw in text.splitlines():
        m = re.match(r"^\s*([0-9a-fA-F]+)\s+([^\s]+)(?:\s+(.*))?$", raw)
        if m:
            rows.append((int(m.group(1), 16), m.group(2),
                         (m.group(3) or "").strip(), raw))
    return rows

def group_rows(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for row in rows:
        while si + 1 < len(symbols) and symbols[si + 1][0] <= row[0]:
            si += 1
        if symbols[si][0] <= row[0]:
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
    result = []
    for token in HEX_RE.findall(row[2]):
        try:
            result.append(int(token, 16))
        except ValueError:
            pass
    return result

def has_literal(rows, value):
    for row in rows:
        if value in immediates(row):
            return True
    return False

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
    callers = exact_indices(symbols, caller)
    callees = exact_indices(symbols, callee)
    if len(callers) != 1 or len(callees) != 1:
        return False
    target_addr = symbols[callees[0]][0]
    for row in groups.get(callers[0], []):
        if branch_hits_target(row, callee, target_addr):
            return True
    return False

def emit_body(fp, symbols, groups, name):
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

def emit_fields(fp, label, rows, fields):
    line(fp)
    line(fp, "== Field closure: %s ==" % label)
    complete = True
    for value in fields:
        hits = [row for row in rows if value in immediates(row)]
        line(fp, "field=0x%x count=%d" % (value, len(hits)))
        if not hits:
            complete = False
        for row in hits:
            line(fp, "field_hit=0x%x site=0x%x raw=%s" % (value, row[0], row[3]))
    line(fp, "field_closure_complete=%s" % ("YES" if complete else "NO"))
    return complete

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-event-unflip-source-helper.")

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
            line(fp, "== PPC Carbon GUI event-unflip direct-source helper contract audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % (mode or "unsupported"))
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "prior_image_local_repair_surface=PASS")
            line(fp, "coregraphics_text_patch_authorized=NO")
            line(fp, "helper_injection_authorized=NO")
            line(fp, "persistent_projection_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

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

                    line(fp)
                    line(fp, "== Required target inventory ==")
                    for name in cfg["targets"]:
                        count = len(exact_indices(symbols, name))
                        line(fp, "target=%s count=%d" % (name, count))
                        if count != 1:
                            issues.append("expected exactly one target: %s" % name)

                    line(fp)
                    line(fp, "== Required direct edges ==")
                    for caller, callee in cfg["edges"]:
                        present = has_edge(symbols, groups, caller, callee)
                        line(fp, "edge=%s->%s present=%s" %
                             (caller, callee, "YES" if present else "NO"))
                        if not present:
                            issues.append("missing direct edge: %s -> %s" % (caller, callee))

                    event_rows = body_for(symbols, groups, "_CGSGetUnflippedEventLocation")
                    main_rows = body_for(symbols, groups, "_lookupMainDisplay")
                    master_rows = body_for(symbols, groups, "_lookupMasterDisplay")
                    bounds_rows = body_for(symbols, groups, "_CGSGetDisplayBounds")
                    mapping_rows = body_for(symbols, groups, cfg["mapping_init"])

                    main_ok = emit_fields(fp, "_lookupMainDisplay", main_rows, cfg["main_fields"])
                    master_ok = emit_fields(fp, "_lookupMasterDisplay", master_rows, cfg["master_fields"])
                    bounds_ok = emit_fields(fp, "_CGSGetDisplayBounds", bounds_rows, cfg["bounds_fields"])

                    source_stride_ok = has_literal(mapping_rows, cfg["source_stride"])
                    local_stride_ok = has_literal(mapping_rows, cfg["local_stride"])
                    record_base_ok = has_literal(mapping_rows, 0x20)
                    event_cache_ok = has_literal(event_rows, cfg["event_cache_offset"])

                    line(fp)
                    line(fp, "== Direct-source helper boundary markers ==")
                    line(fp, "source_record_base_0x20_present=%s" % ("YES" if record_base_ok else "NO"))
                    line(fp, "source_record_stride=0x%x present=%s" %
                         (cfg["source_stride"], "YES" if source_stride_ok else "NO"))
                    line(fp, "local_mapping_stride=0x%x present=%s" %
                         (cfg["local_stride"], "YES" if local_stride_ok else "NO"))
                    line(fp, "event_cached_extent_offset=0x%x present=%s" %
                         (cfg["event_cache_offset"], "YES" if event_cache_ok else "NO"))
                    line(fp, "main_record_field_closure=%s" % ("YES" if main_ok else "NO"))
                    line(fp, "master_record_field_closure=%s" % ("YES" if master_ok else "NO"))
                    line(fp, "bounds_record_field_closure=%s" % ("YES" if bounds_ok else "NO"))
                    if mode == "snow":
                        line(fp, "snow_bounds_local_entry_0x48_dependency=%s" %
                             ("YES" if has_literal(bounds_rows, 0x48) else "NO"))
                        line(fp, "ppc_byte_swap_instruction_in_lookupDisplay=%s" %
                             ("YES" if any(row[1] == "lwbrx" for row in body_for(symbols, groups, "_lookupDisplay")) else "NO"))
                    else:
                        line(fp, "lion_native_bounds_local_entry_0x48_dependency=%s" %
                             ("YES" if has_literal(bounds_rows, 0x48) else "NO"))

                    if not source_stride_ok:
                        issues.append("source stride literal missing")
                    if not local_stride_ok:
                        issues.append("local mapping stride literal missing")
                    if not record_base_ok:
                        issues.append("source record +0x20 base literal missing")
                    if not event_cache_ok:
                        issues.append("event cached extent offset missing")
                    if not main_ok:
                        issues.append("main record field closure incomplete")
                    if not master_ok:
                        issues.append("master record field closure incomplete")
                    if not bounds_ok:
                        issues.append("bounds record field closure incomplete")

                    line(fp)
                    line(fp, "== Accepted prior ownership/lifecycle facts ==")
                    line(fp, "server_owned_source_write_authorized=NO")
                    line(fp, "source_array_runtime_resolution=DECODE_LOADED_LOOKUPMAIN_PIC")
                    line(fp, "local_mapping_projection_required_for_this_audit=NO")
                    line(fp, "release_rebind_may_consume_mis_strided_local_entries=YES")
                    line(fp, "display_server_shutdown_clears_source_state=YES")
                    line(fp, "notification_update_path_requires_review_for_source_only_helper=YES")

                    for name in [
                        "_CGSGetUnflippedEventLocation",
                        "_lookupMainDisplay",
                        "_lookupMasterDisplay",
                        "_lookupDisplay",
                        "_CGSGetDisplayBounds",
                        cfg["mapping_init"],
                        "_updateAllDisplayInfoAsNeeded",
                        "_CGSReleaseAllDisplays",
                        cfg["notify"],
                        "_CGSDisplayServerShutdown",
                    ]:
                        emit_body(fp, symbols, groups, name)

            line(fp)
            line(fp, "== Decision questions ==")
            line(fp, "question_1=Can a translated-PPC-on-Lion helper scan the active server-owned source read-only as count + records at source+0x20+i*0x17c, instead of consuming Snow's 0x58 local entries whose record pointers were built with 0x150 source stride?")
            line(fp, "question_2=Can the Lion-native main selection be reproduced from the closed +0x1c identity/status field set, resolving any linked display IDs by rescanning the same 0x17c source records?")
            line(fp, "question_3=Can the Lion-native master-display redirect be reproduced using only record +0x12e and +0x114, again by direct source scan rather than _lookupDisplay?")
            line(fp, "question_4=Can the Lion-native bounds result be produced solely from record +0x131 and the +0xdc..+0xf8 geometry fields, avoiding Snow's local-entry +0x48 branch?")
            line(fp, "question_5=Does the release/rebind/notification lifecycle leave the active source mapping readable and stable under the display lock without requiring a partial Snow-layout local projection to remain installed?")
            line(fp, "question_6=If the source-only contract closes, should the next step audit one event-unflip-only out-of-line patch boundary that bypasses both private main lookup and private bounds lookup; otherwise must the project return to a complete lifecycle projection design?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "event_unflip_direct_source_helper_contract_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No mouse/titlebar gesture was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "No CoreGraphics text or data was modified.")
            line(fp, "No helper or interposer was built or loaded.")
            line(fp, "No process-local mapping pointer was written.")
            line(fp, "No server-owned shared memory was written.")
            line(fp, "No private CoreGraphics function was called.")
            line(fp, "No display ID was substituted.")
            line(fp, "Temporary architecture slices were removed on exit.")
            line(fp, "No WindowServer, Rosetta cache, dyld, or XNU state was modified.")

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
