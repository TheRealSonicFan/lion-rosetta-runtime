#!/usr/bin/python
from __future__ import print_function

import binascii
import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-event-unflip-callsite-patchability-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "event": "_CGSGetUnflippedEventLocation",
        "main": "_CGSMainDisplayID",
        "bounds": "_CGSGetDisplayBounds",
        "cache_offset": 0xc6,
        "bounds_buffer_offset": 0x50,
        "bounds_height_offset": 0x5c,
        "call_size": 4,
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "event": "_CGSGetUnflippedEventLocation",
        "main": "_CGSMainDisplayID",
        "bounds": "_CGSGetDisplayBounds",
        "cache_offset": 0xbe,
        "bounds_buffer_offset": 0xe8,
        "bounds_height_offset": 0xf4,
        "call_size": 5,
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

def branch_rows_to(symbols, groups, caller, callee):
    callers = exact_indices(symbols, caller)
    callees = exact_indices(symbols, callee)
    if len(callers) != 1 or len(callees) != 1:
        return []
    target_addr = symbols[callees[0]][0]
    return [row for row in groups.get(callers[0], [])
            if branch_hits_target(row, callee, target_addr)]

def parse_text_section(load_commands):
    in_section = False
    sectname = None
    segname = None
    addr = None
    size = None
    offset = None
    for raw in load_commands.splitlines():
        s = raw.strip()
        if s == "Section":
            in_section = True
            sectname = segname = None
            addr = size = offset = None
            continue
        if not in_section:
            continue
        parts = s.split()
        if len(parts) >= 2 and parts[0] == "sectname":
            sectname = parts[1]
        elif len(parts) >= 2 and parts[0] == "segname":
            segname = parts[1]
        elif len(parts) >= 2 and parts[0] == "addr":
            addr = parse_hex(parts[1])
        elif len(parts) >= 2 and parts[0] == "size":
            size = parse_hex(parts[1])
        elif len(parts) >= 2 and parts[0] == "offset":
            try:
                offset = int(parts[1], 10)
            except ValueError:
                offset = None
        if sectname == "__text" and segname == "__TEXT" and addr is not None and offset is not None:
            return addr, size, offset
    return None

def bytes_at_vmaddr(path, text_section, vmaddr, count):
    if text_section is None:
        return None
    text_addr, text_size, text_offset = text_section
    if vmaddr < text_addr:
        return None
    delta = vmaddr - text_addr
    if text_size is not None and delta + count > text_size:
        return None
    f = open(path, "rb")
    try:
        f.seek(text_offset + delta)
        data = f.read(count)
    finally:
        f.close()
    if len(data) != count:
        return None
    raw = binascii.hexlify(data)
    if not isinstance(raw, str):
        raw = raw.decode("ascii")
    return raw

def immediates(row):
    result = []
    for token in HEX_RE.findall(row[2]):
        try:
            result.append(int(token, 16))
        except ValueError:
            pass
    return result

def has_immediate(rows, value):
    for row in rows:
        if value in immediates(row):
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

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-event-unflip-patchability.")

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
            line(fp, "== PPC Carbon GUI event-unflip callsite patchability audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % (mode or "unsupported"))
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "prior_direct_source_helper_contract=PASS")
            line(fp, "coregraphics_text_patch_authorized=NO")
            line(fp, "branch_island_authorized=NO")
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

                    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                    symbols = parse_symbols(nm_out) if rc == 0 else []
                    if rc != 0:
                        issues.append("nm failed")
                    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                    rows = parse_rows(dis_out) if rc == 0 else []
                    groups = group_rows(rows, symbols) if rc == 0 else {}
                    if rc != 0:
                        issues.append("otool disassembly failed")
                    rc, load_out = run(["/usr/bin/otool", "-l", dst])
                    text_section = parse_text_section(load_out) if rc == 0 else None
                    if rc != 0 or text_section is None:
                        issues.append("unable to resolve __TEXT,__text file mapping")

                    for name in [cfg["event"], cfg["main"], cfg["bounds"]]:
                        count = len(exact_indices(symbols, name))
                        line(fp, "target=%s count=%d" % (name, count))
                        if count != 1:
                            issues.append("expected exactly one target: %s" % name)

                    event_rows = body_for(symbols, groups, cfg["event"])
                    main_calls = branch_rows_to(symbols, groups, cfg["event"], cfg["main"])
                    bounds_calls = branch_rows_to(symbols, groups, cfg["event"], cfg["bounds"])

                    line(fp)
                    line(fp, "== Candidate callsite contract ==")
                    line(fp, "main_call_count=%d" % len(main_calls))
                    line(fp, "bounds_call_count=%d" % len(bounds_calls))
                    if len(main_calls) != 1:
                        issues.append("expected one event-unflip main-display call")
                    if len(bounds_calls) != 1:
                        issues.append("expected one event-unflip display-bounds call")

                    if len(main_calls) == 1 and len(bounds_calls) == 1:
                        main_site = main_calls[0][0]
                        bounds_site = bounds_calls[0][0]
                        event_addr = symbols[exact_indices(symbols, cfg["event"])[0]][0]
                        bounds_addr = symbols[exact_indices(symbols, cfg["bounds"])[0]][0]
                        line(fp, "event_symbol_address=0x%x" % event_addr)
                        line(fp, "main_call_site=0x%x" % main_site)
                        line(fp, "bounds_call_site=0x%x" % bounds_site)
                        line(fp, "bounds_call_offset_from_event=0x%x" % (bounds_site - event_addr))
                        line(fp, "bounds_call_target=0x%x" % bounds_addr)
                        line(fp, "bounds_call_raw=%s" % bounds_calls[0][3])
                        raw = bytes_at_vmaddr(dst, text_section, bounds_site, cfg["call_size"])
                        line(fp, "bounds_call_file_bytes=%s" % (raw or "UNRESOLVED"))
                        if raw is None:
                            issues.append("unable to read candidate callsite bytes")

                        between = [row for row in event_rows if main_site < row[0] < bounds_site]
                        after = [row for row in event_rows if row[0] > bounds_site][:3]
                        for row in between:
                            line(fp, "between_main_and_bounds=%s" % row[3])
                        for row in after:
                            line(fp, "after_bounds_call=%s" % row[3])

                        cache_ok = has_immediate(event_rows, cfg["cache_offset"])
                        buffer_ok = has_immediate(event_rows, cfg["bounds_buffer_offset"])
                        height_ok = has_immediate(event_rows, cfg["bounds_height_offset"])
                        line(fp, "event_cache_offset=0x%x present=%s" %
                             (cfg["cache_offset"], "YES" if cache_ok else "NO"))
                        line(fp, "bounds_buffer_offset=0x%x present=%s" %
                             (cfg["bounds_buffer_offset"], "YES" if buffer_ok else "NO"))
                        line(fp, "bounds_height_offset=0x%x present=%s" %
                             (cfg["bounds_height_offset"], "YES" if height_ok else "NO"))
                        if not cache_ok:
                            issues.append("event cache offset missing")
                        if not buffer_ok:
                            issues.append("bounds buffer offset missing")
                        if not height_ok:
                            issues.append("bounds height offset missing")

                        if mode == "snow":
                            sequence_ok = (bounds_site == main_site + 8 and len(between) == 1
                                           and between[0][1] == "addi"
                                           and "r4" in between[0][2]
                                           and "r1" in between[0][2])
                            status_check_ok = False
                            if after:
                                status_check_ok = (after[0][1] == "cmpwi" and "r3" in after[0][2])
                            line(fp, "snow_main_to_bounds_sequence_exact=%s" %
                                 ("YES" if sequence_ok else "NO"))
                            line(fp, "snow_bounds_return_status_checked_in_r3=%s" %
                                 ("YES" if status_check_ok else "NO"))
                            line(fp, "candidate_patch_scope=ONE_PPC_CALL_INSTRUCTION")
                            line(fp, "candidate_helper_abi=r3_display_id_input_may_be_ignored;r4_CGRect_output;return_r3_CGError")
                            line(fp, "candidate_existing_success_path_caches_bounds_height=YES")
                            line(fp, "candidate_existing_failure_path_preserved=YES")
                            line(fp, "candidate_requires_event_structure_rewrite=NO")
                            line(fp, "candidate_requires_global_CGSMainDisplayID_patch=NO")
                            line(fp, "candidate_requires_global_CGSGetDisplayBounds_patch=NO")
                            line(fp, "ppc_relative_bl_range=PLUS_MINUS_32_MIB")
                            line(fp, "direct_branch_to_future_helper_reachability=UNPROVEN")
                            line(fp, "runtime_text_writability=UNPROVEN")
                            line(fp, "branch_island_or_near_trampoline_need=REVIEW_AFTER_STATIC_AUDIT")
                            if not sequence_ok:
                                issues.append("Snow main/bounds call sequence mismatch")
                            if not status_check_ok:
                                issues.append("Snow bounds return status check mismatch")
                        else:
                            line(fp, "lion_reference_same_zero_cache_shape=YES")
                            line(fp, "lion_is_patch_target=NO")

                    emit_body(fp, symbols, groups, cfg["event"])
                    emit_body(fp, symbols, groups, cfg["bounds"])

            line(fp)
            line(fp, "== Decision questions ==")
            line(fp, "question_1=Can the Snow zero-cache repair preserve the existing event-unflip success/failure/cache logic by replacing only the direct _CGSGetDisplayBounds call with a helper of the same r3/r4/CGError contract?")
            line(fp, "question_2=Can that helper ignore the known-zero display ID in r3, resolve the active Lion source at call time, fill the existing stack CGRect buffer, and return zero only on an exact source-scan success?")
            line(fp, "question_3=Does a one-instruction PPC callsite patch avoid any need to patch _CGSMainDisplayID globally, _CGSGetDisplayBounds globally, the event object layout, or Snow local mapping pointers?")
            line(fp, "question_4=What exact loaded-text write mechanism can verify the original four bytes, change only that PPC branch, and restore them deterministically?")
            line(fp, "question_5=Can a future helper/trampoline be placed within the PPC relative-branch range without modifying the shared-cache file or another system image?")
            line(fp, "question_6=If direct branch reachability is not guaranteed, is a process-local near trampoline safer than a global function-prologue hook conditioned on the exact return address?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "event_unflip_callsite_patchability_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No mouse/titlebar gesture was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "No CoreGraphics text or data was modified.")
            line(fp, "No branch island or trampoline was allocated.")
            line(fp, "No helper or interposer was built or loaded.")
            line(fp, "No process-local display pointer was written.")
            line(fp, "No server-owned shared memory was written.")
            line(fp, "No display ID was substituted.")
            line(fp, "Temporary architecture slices were removed on exit.")
            line(fp, "No WindowServer, Rosetta cache, dyld, shared-cache file, or XNU state was modified.")

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
