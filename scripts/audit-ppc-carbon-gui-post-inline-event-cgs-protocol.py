#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-post-inline-event-cgs-protocol-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

SNOW_PRODUCT = "10.6.8"
SNOW_BUILD = "10K549"
LION_PRODUCT = "10.7.5"
LION_BUILD = "11G63"
SNOW_ARCH = "ppc7400"
LION_ARCH = "i386"

# These are observations from the accepted Snow control and the returned Lion
# post-inline run. They are anchors only; this audit does not assume that the
# same request ID names the same native routine on both releases.
LIVE_ANCHORS = [
    ("post_inline_724e", 0x0000724e, 0x000072b2, 0x24, 0x3c),
    ("post_inline_7258", 0x00007258, 0x000072bc, 0x24, 0x38),
    ("post_inline_7293", 0x00007293, 0x000072f7, 0x18, 0x3c),
    ("post_inline_721f", 0x0000721f, 0x00007283, 0x24, 0x30),
]

TARGET_PATTERNS = [
    ("get_window_bounds", re.compile(r"CGS.*GetWindowBounds|GetWindowBounds", re.I)),
    ("find_shared_window", re.compile(r"CGS.*FindSharedWindow|FindSharedWindow", re.I)),
    ("next_event_outofline", re.compile(r"CGS.*GetNextEventRecord|GetNextEventRecord|CGSGetPortStreamOutofline", re.I)),
    ("get_display_bounds", re.compile(r"CGS.*GetDisplayBounds|GetDisplayBounds", re.I)),
]

FOCUS_RE = re.compile(
    r"(GetWindowBounds|FindSharedWindow|GetNextEventRecord|GetPortStreamOutofline|"
    r"GetDisplayBounds|mach_msg|mig_get_reply_port|mig_put_reply_port|"
    r"mig_dealloc_reply_port|MIG_|NDR|WindowServer|windowserver)",
    re.I,
)
STRING_RE = re.compile(
    r"(GetWindowBounds|FindSharedWindow|GetNextEventRecord|GetDisplayBounds|"
    r"CGSDeviceCreate|Invalid window|MIG:)",
    re.I,
)
HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")

REQUEST_RANGE = (0x000071f0, 0x000072c0)
REPLY_RANGE = (0x00007250, 0x00007320)
SIZE_VALUES = set([0x18, 0x24, 0x28, 0x30, 0x34, 0x38, 0x3c, 0x40, 0x1e4, 0x4030])
BITS_VALUE = 0x00001513


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


def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def parse_hex_token(token):
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


def thin_arch(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out


def parse_symbols(text):
    symbols = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in line:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        symbols.append((addr, parts[-1], line))
    symbols.sort()
    return symbols


def parse_rows(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, line))
    return rows


def next_symbol_address(symbols, index):
    if index + 1 < len(symbols):
        return symbols[index + 1][0]
    return None


def symbol_rows(rows, symbols, index, max_bytes=0x10000):
    start = symbols[index][0]
    end = start + max_bytes
    nxt = next_symbol_address(symbols, index)
    if nxt is not None:
        end = min(end, nxt)
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]


def group_rows_by_symbol(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for addr, line in rows:
        while si + 1 < len(symbols) and symbols[si + 1][0] <= addr:
            si += 1
        if symbols[si][0] <= addr:
            groups.setdefault(si, []).append((addr, line))
    return groups


def values_in_line(line):
    values = []
    for token in HEX_RE.findall(line):
        try:
            values.append(int(token, 16))
        except ValueError:
            pass
    return values


def values_in_selected(selected):
    values = set()
    for addr, line in selected:
        for value in values_in_line(line):
            values.add(value)
    return values


def interesting_value(value):
    return ((REQUEST_RANGE[0] <= value <= REQUEST_RANGE[1]) or
            (REPLY_RANGE[0] <= value <= REPLY_RANGE[1]) or
            value in SIZE_VALUES or value == BITS_VALUE)


def has_mig_transport(selected):
    for addr, line in selected:
        lower = line.lower()
        if ("mach_msg" in lower or "mig_get_reply_port" in lower or
                "mig_put_reply_port" in lower or
                "mig_dealloc_reply_port" in lower):
            return True
    return False


def emit_cache_provenance(fp):
    write_line(fp)
    write_line(fp, "== Rosetta shared-cache provenance ==")
    if os.path.isfile(ROSETTA_CACHE):
        write_line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
    else:
        write_line(fp, "rosetta_cache=MISSING")
    if os.path.isfile(ROSETTA_MAP):
        write_line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
        try:
            data = open(ROSETTA_MAP, "r").read()
            hits = [line for line in data.splitlines() if COREGRAPHICS in line]
            write_line(fp, "cache_map_contains_coregraphics=%s" %
                       ("YES" if hits else "NO"))
            for line in hits[:8]:
                write_line(fp, line)
        except IOError as e:
            write_line(fp, "rosetta_cache_map_read_error=%s" % e)
    else:
        write_line(fp, "rosetta_cache_map=MISSING")


def emit_anchor_context(fp, rows, symbols, label, value):
    forms = ["0x%x" % value, "0x%08x" % value]
    hits = []
    for i, item in enumerate(rows):
        lower = item[1].lower()
        if any(form.lower() in lower for form in forms):
            hits.append(i)
    write_line(fp, "%s=0x%08x instruction_hits=%d" % (label, value, len(hits)))
    emitted = set()
    for i in hits[:24]:
        start = max(0, i - 8)
        end = min(len(rows), i + 9)
        key = (start, end)
        if key in emitted:
            continue
        emitted.add(key)
        write_line(fp, "-- %s context rows %d..%d --" %
                   (label, start, end - 1))
        for j in range(start, end):
            write_line(fp, rows[j][1])
    return len(hits)


def emit_symbol(fp, rows, symbols, groups, index, label):
    start, name, raw_symbol = symbols[index]
    selected = groups.get(index, symbol_rows(rows, symbols, index))
    write_line(fp)
    write_line(fp, "== %s: %s ==" % (label, name))
    write_line(fp, "symbol_address=0x%x" % start)
    write_line(fp, "symbol_record=%s" % raw_symbol)
    write_line(fp, "instruction_lines=%d" % len(selected))
    write_line(fp, "has_mig_transport=%s" %
               ("YES" if has_mig_transport(selected) else "NO"))
    vals = sorted(set(value for addr, line in selected
                      for value in values_in_line(line)
                      if interesting_value(value)))
    write_line(fp, "protocol_values=%s" %
               ",".join("0x%08x" % value for value in vals))
    write_line(fp, "-- full symbol window --")
    for addr, line in selected:
        write_line(fp, line)


def emit_callers(fp, groups, symbols, target_index):
    target_addr, target_name, raw_symbol = symbols[target_index]
    forms = ["0x%x" % target_addr, "0x%08x" % target_addr]
    lower_name = target_name.lower()
    hits = []
    for i, selected in groups.items():
        if i == target_index:
            continue
        for addr, line in selected:
            lower = line.lower()
            if lower_name in lower or any(form in lower for form in forms):
                hits.append((i, line))
    write_line(fp, "caller_reference_count=%d" % len(hits))
    for i, line in hits[:96]:
        write_line(fp, "caller=%s@0x%x line=%s" %
                   (symbols[i][1], symbols[i][0], line))


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-post-inline-cgs.")

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
            write_line(fp, "== PPC Carbon GUI post-inline event CGS protocol audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "mode=%s" % mode)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            write_line(fp, "live_boundary=inline_next_event_adapter_passed_but_dispatcher_received_no_mouse_events")
            write_line(fp, "live_lion_diagnostic_1=CGSGetWindowBounds_server_type_check_failure")
            write_line(fp, "live_lion_diagnostic_2=_CGSFindSharedWindow_client_type_check_failure_WID_8")
            write_line(fp, "live_lion_diagnostic_3=CGSGetNextEventRecord_Outofline_server_type_check_failure")
            write_line(fp, "live_lion_diagnostic_4=CGSGetDisplayBounds_illegal_display_0")

            write_line(fp)
            write_line(fp, "== Live anchor geometry ==")
            for label, request_id, reply_id, send_size, recv_size in LIVE_ANCHORS:
                write_line(fp, "%s_request_id=0x%08x" % (label, request_id))
                write_line(fp, "%s_reply_id=0x%08x" % (label, reply_id))
                write_line(fp, "%s_send_size=0x%x" % (label, send_size))
                write_line(fp, "%s_recv_size=0x%x" % (label, recv_size))

            emit_cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== CoreGraphics ==")
            write_line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                write_line(fp, "state=MISSING")
                issues.append("CoreGraphics binary missing")
            elif arch is not None:
                write_line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                rc, out = run(["/usr/bin/file", COREGRAPHICS])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREGRAPHICS])
                write_line(fp, out.rstrip())

                thin = os.path.join(tempdir, "CoreGraphics.%s" % arch)
                ok, out = thin_arch(COREGRAPHICS, arch, thin)
                write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    write_line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing: %s" % arch)
                else:
                    write_line(fp, "slice_sha256=%s" % sha256(thin))

                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        write_line(fp, "nm_failed")
                        write_line(fp, nm_out.rstrip())
                        issues.append("nm failed")
                        symbols = []
                    else:
                        symbols = parse_symbols(nm_out)
                        write_line(fp, "parsed_text_symbols=%d" % len(symbols))
                        write_line(fp)
                        write_line(fp, "== Focused symbol inventory ==")
                        focused = [line for line in nm_out.splitlines()
                                   if FOCUS_RE.search(line)]
                        for line in focused[:2400]:
                            write_line(fp, line)
                        if len(focused) > 2400:
                            write_line(fp, "additional_focused_symbols_omitted=%d" %
                                       (len(focused) - 2400))

                    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
                    write_line(fp)
                    write_line(fp, "== Focused strings ==")
                    if rc == 0:
                        hits = [line for line in strings_out.splitlines()
                                if STRING_RE.search(line)]
                        for line in hits[:1200]:
                            write_line(fp, line)
                        if len(hits) > 1200:
                            write_line(fp, "additional_string_hits_omitted=%d" %
                                       (len(hits) - 1200))
                    else:
                        write_line(fp, "strings_failed")

                    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                    if rc != 0:
                        write_line(fp, "otool_disassembly_failed")
                        write_line(fp, dis_out.rstrip())
                        issues.append("otool disassembly failed")
                    else:
                        rows = parse_rows(dis_out)
                        groups = group_rows_by_symbol(rows, symbols)
                        write_line(fp, "parsed_instruction_lines=%d" % len(rows))

                        write_line(fp)
                        write_line(fp, "== Target family ==")
                        all_targets = set()
                        target_counts = {}
                        for label, pattern in TARGET_PATTERNS:
                            idxs = [i for i, item in enumerate(symbols)
                                    if pattern.search(item[1])]
                            target_counts[label] = len(idxs)
                            write_line(fp, "%s_symbol_count=%d" % (label, len(idxs)))
                            for i in idxs:
                                all_targets.add(i)
                                write_line(fp, "%s_symbol=%s address=0x%x" %
                                           (label, symbols[i][1], symbols[i][0]))

                        for required in ("get_window_bounds", "find_shared_window",
                                         "next_event_outofline"):
                            if target_counts.get(required, 0) == 0:
                                issues.append("target family missing: %s" % required)

                        write_line(fp)
                        write_line(fp, "== Live ID anchors in disassembly ==")
                        for label, request_id, reply_id, send_size, recv_size in LIVE_ANCHORS:
                            req_hits = emit_anchor_context(
                                fp, rows, symbols, label + "_request_anchor", request_id)
                            rep_hits = emit_anchor_context(
                                fp, rows, symbols, label + "_reply_anchor", reply_id)
                            if mode == "snow" and req_hits == 0:
                                issues.append("Snow request anchor missing: 0x%08x" % request_id)
                            if mode == "snow" and rep_hits == 0:
                                issues.append("Snow reply anchor missing: 0x%08x" % reply_id)

                        candidate_symbols = set(all_targets)
                        anchor_values = set()
                        for label, request_id, reply_id, send_size, recv_size in LIVE_ANCHORS:
                            anchor_values.add(request_id)
                            anchor_values.add(reply_id)
                        for i, selected in groups.items():
                            vals = values_in_selected(selected)
                            if vals.intersection(anchor_values) and has_mig_transport(selected):
                                candidate_symbols.add(i)

                        write_line(fp)
                        write_line(fp, "== Narrow generated-MIG candidate inventory ==")
                        write_line(fp, "candidate_symbol_count=%d" %
                                   len(candidate_symbols))
                        for i in sorted(candidate_symbols):
                            vals = sorted(set(value for value in
                                              values_in_selected(groups.get(i, []))
                                              if interesting_value(value)))
                            write_line(fp, "%s@0x%x ids=%s" %
                                       (symbols[i][1], symbols[i][0],
                                        ",".join("0x%08x" % value for value in vals)))

                        for i in sorted(candidate_symbols):
                            emit_symbol(fp, rows, symbols, groups, i,
                                        "candidate/target symbol")
                            emit_callers(fp, groups, symbols, i)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "post_inline_event_cgs_protocol_audit_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Integrity ==")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No CGS, WindowServer, event, mouse, bootstrap, or Mach request was issued.")
            write_line(fp, "CoreGraphics was read only; temporary architecture slices were removed on exit.")
            write_line(fp, "No CoreGraphics, HIToolbox, Rosetta cache, notification, WindowServer, or XNU state was modified.")

        print("Created: %s" % report)
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
