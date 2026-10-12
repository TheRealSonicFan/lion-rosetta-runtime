#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-showwindow-post-tracking-cgs-protocol.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

OBSERVED = [
    ("first_post_s00_failure", 0x000072e7, 0x0000734b),
    ("second_post_s00_failure", 0x000072f2, 0x00007356),
]

REQUEST_RANGE = (0x000072c0, 0x00007310)
REPLY_RANGE = (0x00007320, 0x00007380)

DIAGNOSTIC_RE = re.compile(
    r"(ColorProfile|ColorSpace|ColorTransform|WindowColor|CGWindowContext|"
    r"CGSShapeWindow|mach_msg|mig_get_reply_port|mig_put_reply_port|"
    r"mig_dealloc_reply_port|MIG_|NDR|WindowServer|windowserver)",
    re.I,
)
STRING_RE = re.compile(
    r"(ColorProfile|ColorSpace|ColorTransform|WindowColor|CGWindowContext|"
    r"CGSShapeWindow|WindowServer|windowserver|CGS)",
    re.I,
)
HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")

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
    ordered = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None or "(__TEXT,__text)" not in line:
            continue
        ordered.append((addr, parts[-1]))
    ordered.sort()
    return ordered

def parse_instructions(text):
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

def symbol_window(rows, symbols, index, max_bytes=0x10000):
    start = symbols[index][0]
    end = start + max_bytes
    nxt = next_symbol_address(symbols, index)
    if nxt is not None:
        end = min(end, nxt)
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]

def enclosing_symbol(symbols, addr):
    best = None
    for i, item in enumerate(symbols):
        if item[0] > addr:
            break
        best = (i, item[0], item[1])
    return best

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

def in_candidate_range(value):
    return ((REQUEST_RANGE[0] <= value <= REQUEST_RANGE[1]) or
            (REPLY_RANGE[0] <= value <= REPLY_RANGE[1]))

def cache_provenance(fp):
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

def emit_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "== focused cstrings ==")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "otool_cstring_dump_failed")
        return
    hits = [line for line in out.splitlines() if STRING_RE.search(line)]
    for line in hits[:1600]:
        write_line(fp, line)
    if len(hits) > 1600:
        write_line(fp, "additional_cstring_hits_omitted=%d" % (len(hits) - 1600))

def emit_symbol(fp, rows, symbols, index, groups):
    start, name = symbols[index]
    selected = groups.get(index, [])
    write_line(fp)
    write_line(fp, "== candidate symbol: %s ==" % name)
    write_line(fp, "symbol_address=0x%x" % start)
    write_line(fp, "instruction_lines=%d" % len(selected))
    write_line(fp, "-- full symbol window --")
    for addr, line in selected:
        write_line(fp, line)
    write_line(fp, "-- MIG transport lines --")
    mig = [line for addr, line in selected
           if ("mach_msg" in line or "mig_get_reply_port" in line or
               "mig_put_reply_port" in line or "mig_dealloc_reply_port" in line)]
    if mig:
        for line in mig:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")
    write_line(fp, "-- candidate ID immediates --")
    found = []
    for addr, line in selected:
        for value in values_in_line(line):
            if in_candidate_range(value):
                found.append((value, line))
    if found:
        for value, line in found:
            write_line(fp, "id=0x%08x line=%s" % (value, line))
    else:
        write_line(fp, "NONE")

def emit_anchor_context(fp, rows, symbols):
    write_line(fp)
    write_line(fp, "== observed legacy ID anchors ==")
    anchor_symbols = set()
    hit_counts = {}
    all_ids = []
    for label, request_id, reply_id in OBSERVED:
        all_ids.append((label, "request", request_id))
        all_ids.append((label, "reply", reply_id))

    for label, kind, target in all_ids:
        forms = ["0x%x" % target, "0x%08x" % target]
        hits = []
        for i, item in enumerate(rows):
            lower = item[1].lower()
            if any(form.lower() in lower for form in forms):
                hits.append(i)
        hit_counts[(label, kind)] = len(hits)
        write_line(fp, "%s_%s_id=0x%08x instruction_hits=%d" %
                   (label, kind, target, len(hits)))
        emitted = set()
        for i in hits:
            sym = enclosing_symbol(symbols, rows[i][0])
            if sym is not None:
                anchor_symbols.add(sym[0])
                write_line(fp, "anchor_symbol=%s@0x%x" % (sym[2], sym[1]))
            start = max(0, i - 10)
            end = min(len(rows), i + 11)
            key = (start, end)
            if key in emitted:
                continue
            emitted.add(key)
            write_line(fp, "-- anchor context rows %d..%d --" % (start, end - 1))
            for j in range(start, end):
                write_line(fp, rows[j][1])
    return anchor_symbols, hit_counts

def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-showwindow-post-tracking-cgs.")

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8":
            required_arch = "ppc7400"
        elif product == "10.7.5":
            required_arch = "i386"
        else:
            required_arch = None
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager ShowWindow post-tracking CGS protocol audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" %
                       (required_arch if required_arch else "UNSUPPORTED"))
            for label, request_id, reply_id in OBSERVED:
                write_line(fp, "%s_request_id=0x%08x" % (label, request_id))
                write_line(fp, "%s_reply_id=0x%08x" % (label, reply_id))

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())
            cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== CoreGraphics ==")
            write_line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                issues.append("CoreGraphics binary missing")
                write_line(fp, "state=MISSING")
            elif required_arch is not None:
                write_line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                rc, out = run(["/usr/bin/file", COREGRAPHICS])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREGRAPHICS])
                write_line(fp, out.rstrip())

                thin = os.path.join(tempdir, "CoreGraphics.%s" % required_arch)
                ok, out = thin_arch(COREGRAPHICS, required_arch, thin)
                write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    write_line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing: %s" % required_arch)
                else:
                    write_line(fp, "slice_sha256=%s" % sha256(thin))
                    emit_cstrings(fp, thin)

                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        issues.append("nm failed")
                        write_line(fp, "nm_failed")
                    else:
                        symbols = parse_symbols(nm_out)
                        write_line(fp, "parsed_text_symbols=%d" % len(symbols))
                        write_line(fp)
                        write_line(fp, "== diagnostic-family symbols ==")
                        family_hits = []
                        for i, item in enumerate(symbols):
                            if DIAGNOSTIC_RE.search(item[1]):
                                family_hits.append(i)
                                write_line(fp, "%s@0x%x" % (item[1], item[0]))
                        write_line(fp, "diagnostic_family_symbol_count=%d" % len(family_hits))

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                        if rc != 0:
                            issues.append("otool disassembly failed")
                            write_line(fp, "otool_disassembly_failed")
                        else:
                            rows = parse_instructions(dis_out)
                            write_line(fp, "parsed_instruction_lines=%d" % len(rows))
                            groups = group_rows_by_symbol(rows, symbols)
                            anchor_symbols, hit_counts = emit_anchor_context(
                                fp, rows, symbols)

                            candidate_symbols = set(anchor_symbols)
                            for i, selected in groups.items():
                                has_mach = any("mach_msg" in line for addr, line in selected)
                                if not has_mach:
                                    continue
                                ids = []
                                for addr, line in selected:
                                    for value in values_in_line(line):
                                        if in_candidate_range(value):
                                            ids.append(value)
                                if ids:
                                    candidate_symbols.add(i)

                            write_line(fp)
                            write_line(fp, "== narrow generated-MIG candidate inventory ==")
                            write_line(fp, "candidate_symbol_count=%d" % len(candidate_symbols))
                            for i in sorted(candidate_symbols):
                                start, name = symbols[i]
                                selected = groups.get(i, [])
                                ids = sorted(set(value
                                    for addr, line in selected
                                    for value in values_in_line(line)
                                    if in_candidate_range(value)))
                                write_line(fp, "%s@0x%x ids=%s" %
                                           (name, start,
                                            ",".join("0x%08x" % value for value in ids)))

                            for i in sorted(candidate_symbols):
                                emit_symbol(fp, rows, symbols, i, groups)

                            if not candidate_symbols:
                                issues.append("no narrow generated-MIG candidates found")
                            if product == "10.6.8":
                                for label, request_id, reply_id in OBSERVED:
                                    if hit_counts.get((label, "request"), 0) == 0:
                                        issues.append("Snow legacy request anchor missing: 0x%08x" %
                                                      request_id)
                                    if hit_counts.get((label, "reply"), 0) == 0:
                                        issues.append("Snow legacy reply anchor missing: 0x%08x" %
                                                      reply_id)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No ShowWindow, CGS, CPS, bootstrap, Mach, or WindowServer request was issued by this audit.")
            write_line(fp, "No CoreGraphics, WindowServer, Rosetta, dyld, launchd, or XNU state was modified by this audit.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

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
