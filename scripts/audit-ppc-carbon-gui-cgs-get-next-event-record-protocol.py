#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-cgs-get-next-event-record-protocol-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

SNOW_PRODUCT = "10.6.8"
SNOW_BUILD = "10K549"
LION_PRODUCT = "10.7.5"
LION_BUILD = "11G63"
SNOW_ARCH = "ppc7400"
LION_ARCH = "i386"

LIVE_LEGACY_REQUEST_ID = 0x00007292
LIVE_LEGACY_REPLY_ID = 0x000072f6
LIVE_REQUEST_BITS = 0x00001513
LIVE_SEND_SIZE = 0x18
LIVE_RECV_SIZE = 0x4030
LIVE_LION_RAW_ERROR_WORD = 0xd0feffff
LIVE_LION_PPC_SWAPPED_ERROR = 0xfffffed0
LIVE_LION_ERROR_SIGNED = -304

TARGET_RE = re.compile(r"CGS.*GetNextEventRecord|GetNextEventRecord", re.I)
FOCUS_RE = re.compile(
    r"(CGS.*GetNextEventRecord|GetNextEventRecord|EventRecord|mach_msg|"
    r"mig_get_reply_port|mig_put_reply_port|mig_dealloc_reply_port|MIG_|NDR|"
    r"WindowServer|windowserver)", re.I)
STRING_RE = re.compile(
    r"(CGS.*GetNextEventRecord|GetNextEventRecord|EventRecord|WindowServer|windowserver|MIG)",
    re.I)
HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")

REQUEST_RANGE = (0x00007270, 0x000072c0)
REPLY_RANGE = (0x000072d0, 0x00007320)
SIZE_VALUES = set([0x18, 0x24, 0x38, 0x3c, 0x40, 0x50, 0x1e4, 0x2a8, 0x4030])


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


def values_in_line(line):
    values = []
    for token in HEX_RE.findall(line):
        try:
            values.append(int(token, 16))
        except ValueError:
            pass
    return values


def interesting_value(value):
    return ((REQUEST_RANGE[0] <= value <= REQUEST_RANGE[1]) or
            (REPLY_RANGE[0] <= value <= REPLY_RANGE[1]) or
            value in SIZE_VALUES)


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
            matches = [line for line in data.splitlines() if COREGRAPHICS in line]
            write_line(fp, "cache_map_contains_coregraphics=%s" %
                       ("YES" if matches else "NO"))
            for line in matches[:8]:
                write_line(fp, line)
        except IOError as e:
            write_line(fp, "rosetta_cache_map_read_error=%s" % e)
    else:
        write_line(fp, "rosetta_cache_map=MISSING")


def emit_anchor_context(fp, rows, label, value):
    forms = ["0x%x" % value, "0x%08x" % value]
    hits = []
    for i, item in enumerate(rows):
        lower = item[1].lower()
        if any(form.lower() in lower for form in forms):
            hits.append(i)
    write_line(fp, "%s=0x%08x instruction_hits=%d" % (label, value, len(hits)))
    emitted = set()
    for i in hits[:32]:
        start = max(0, i - 10)
        end = min(len(rows), i + 11)
        key = (start, end)
        if key in emitted:
            continue
        emitted.add(key)
        write_line(fp, "-- %s context rows %d..%d --" % (label, start, end - 1))
        for j in range(start, end):
            write_line(fp, rows[j][1])
    return len(hits)


def emit_target_symbol(fp, rows, symbols, index):
    start, name, raw_symbol = symbols[index]
    selected = symbol_rows(rows, symbols, index)
    write_line(fp)
    write_line(fp, "== target symbol: %s ==" % name)
    write_line(fp, "symbol_address=0x%x" % start)
    write_line(fp, "symbol_record=%s" % raw_symbol)
    write_line(fp, "instruction_lines=%d" % len(selected))
    write_line(fp, "-- full symbol window --")
    for addr, line in selected:
        write_line(fp, line)

    write_line(fp, "-- direct calls/branches --")
    calls = []
    for addr, line in selected:
        lower = line.lower()
        if ("\tcall" in lower or "\tbl\t" in lower or "\tb\t" in lower or
                "\tjmp" in lower):
            calls.append(line)
    if calls:
        for line in calls:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    write_line(fp, "-- MIG transport lines --")
    mig = []
    for addr, line in selected:
        lower = line.lower()
        if ("mach_msg" in lower or "mig_get_reply_port" in lower or
                "mig_put_reply_port" in lower or
                "mig_dealloc_reply_port" in lower or "ndr" in lower):
            mig.append(line)
    if mig:
        for line in mig:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    write_line(fp, "-- protocol-bearing immediates --")
    found = []
    for addr, line in selected:
        for value in values_in_line(line):
            if interesting_value(value):
                found.append((value, line))
    if found:
        for value, line in found:
            write_line(fp, "value=0x%08x line=%s" % (value, line))
    else:
        write_line(fp, "NONE")


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-cgs-next-event.")

    try:
        rc, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip() if rc == 0 else "UNKNOWN"
        rc, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip() if rc == 0 else "UNKNOWN"

        if product == SNOW_PRODUCT and build == SNOW_BUILD:
            arch = SNOW_ARCH
            mode = "snow"
        elif product == LION_PRODUCT and build == LION_BUILD:
            arch = LION_ARCH
            mode = "lion"
        else:
            arch = None
            mode = "unsupported"
            issues.append("unsupported product/build: %s/%s" % (product, build))

        with open(report, "w") as fp:
            write_line(fp, "== PPC Carbon GUI CGSGetNextEventRecord protocol audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "mode=%s" % mode)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            write_line(fp, "live_legacy_request_id=0x%08x" % LIVE_LEGACY_REQUEST_ID)
            write_line(fp, "live_legacy_reply_id=0x%08x" % LIVE_LEGACY_REPLY_ID)
            write_line(fp, "live_request_bits=0x%08x" % LIVE_REQUEST_BITS)
            write_line(fp, "live_send_size=0x%x" % LIVE_SEND_SIZE)
            write_line(fp, "live_recv_size=0x%x" % LIVE_RECV_SIZE)
            write_line(fp, "live_lion_raw_error_word=0x%08x" % LIVE_LION_RAW_ERROR_WORD)
            write_line(fp, "live_lion_ppc_swapped_error=0x%08x" % LIVE_LION_PPC_SWAPPED_ERROR)
            write_line(fp, "live_lion_error_signed=%d" % LIVE_LION_ERROR_SIGNED)
            write_line(fp, "live_lion_diagnostic=CGSGetNextEventRecord_(Inline)_server_type_check_failure")

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
                        for line in focused[:2500]:
                            write_line(fp, line)
                        if len(focused) > 2500:
                            write_line(fp, "additional_focused_symbols_omitted=%d" %
                                       (len(focused) - 2500))

                    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
                    write_line(fp)
                    write_line(fp, "== Focused strings ==")
                    if rc == 0:
                        string_hits = [line for line in strings_out.splitlines()
                                       if STRING_RE.search(line)]
                        for line in string_hits[:1000]:
                            write_line(fp, line)
                        if len(string_hits) > 1000:
                            write_line(fp, "additional_string_hits_omitted=%d" %
                                       (len(string_hits) - 1000))
                    else:
                        write_line(fp, "strings_failed")

                    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                    if rc != 0:
                        write_line(fp, "otool_disassembly_failed")
                        write_line(fp, dis_out.rstrip())
                        issues.append("otool disassembly failed")
                    else:
                        rows = parse_rows(dis_out)
                        write_line(fp, "parsed_instruction_lines=%d" % len(rows))

                        target_indexes = []
                        for i, item in enumerate(symbols):
                            if TARGET_RE.search(item[1]):
                                target_indexes.append(i)

                        write_line(fp)
                        write_line(fp, "== Target family ==")
                        write_line(fp, "target_symbol_count=%d" % len(target_indexes))
                        for i in target_indexes:
                            write_line(fp, "target_symbol=%s address=0x%x" %
                                       (symbols[i][1], symbols[i][0]))
                        if not target_indexes:
                            issues.append("CGSGetNextEventRecord target family missing")

                        write_line(fp)
                        write_line(fp, "== Live legacy ID anchors ==")
                        req_hits = emit_anchor_context(
                            fp, rows, "legacy_request_anchor", LIVE_LEGACY_REQUEST_ID)
                        rep_hits = emit_anchor_context(
                            fp, rows, "legacy_reply_anchor", LIVE_LEGACY_REPLY_ID)
                        if mode == "snow" and req_hits == 0:
                            issues.append("Snow legacy request anchor missing")
                        if mode == "snow" and rep_hits == 0:
                            issues.append("Snow legacy reply anchor missing")

                        for i in target_indexes:
                            emit_target_symbol(fp, rows, symbols, i)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "cgs_get_next_event_record_protocol_audit_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Integrity ==")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No WindowServer, CGS, event, mouse, or Mach request was issued by this audit.")
            write_line(fp, "CoreGraphics was read only and temporary architecture slices were removed on exit.")
            write_line(fp, "No CoreGraphics, HIToolbox, Rosetta cache, notification, CGS, WindowServer, or XNU state was modified.")

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
