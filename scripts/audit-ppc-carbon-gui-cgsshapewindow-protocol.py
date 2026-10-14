#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./ppc-carbon-gui-cgsshapewindow-protocol.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

LEGACY_REQUEST_ID = 0x0000724d
LEGACY_REPLY_ID = 0x000072b1
CANDIDATE_MIN = 0x00007200
CANDIDATE_MAX = 0x00007420

TARGET_SUBSTRINGS = (
    "CGSShapeWindow",
    "CGSWindowShape",
    "CGSCopyWindowShape",
    "CGSSetWindowShape",
    "CGSGetWindowShape",
)

HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")
DECIMAL_IMMEDIATE_RE = re.compile(r"(?:[$#,]\s*|\s)([0-9]{4,5})(?=\s|,|$)")

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
    for token in DECIMAL_IMMEDIATE_RE.findall(line):
        try:
            values.append(int(token, 10))
        except ValueError:
            pass
    return values

def candidate_ids(selected):
    values = set()
    for addr, line in selected:
        for value in values_in_line(line):
            if CANDIDATE_MIN <= value <= CANDIDATE_MAX:
                values.add(value)
    return sorted(values)

def target_symbol(name):
    return any(token in name for token in TARGET_SUBSTRINGS)

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

def emit_symbol(fp, symbols, index, groups):
    start, name = symbols[index]
    selected = groups.get(index, [])
    write_line(fp)
    write_line(fp, "== shape-family symbol: %s ==" % name)
    write_line(fp, "symbol_address=0x%x" % start)
    write_line(fp, "instruction_lines=%d" % len(selected))
    ids = candidate_ids(selected)
    write_line(fp, "candidate_ids=%s" %
               (",".join("0x%08x" % value for value in ids) if ids else "NONE"))
    write_line(fp, "-- full symbol window --")
    for addr, line in selected:
        write_line(fp, line)
    write_line(fp, "-- direct calls/branches --")
    direct = [line for addr, line in selected
              if ("\tcall" in line or "\tbl" in line or "\tb\t" in line or
                  "\tjmp" in line)]
    if direct:
        for line in direct:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")
    write_line(fp, "-- MIG transport lines --")
    mig = [line for addr, line in selected
           if ("mach_msg" in line or "mig_get_reply_port" in line or
               "mig_put_reply_port" in line or "mig_dealloc_reply_port" in line)]
    if mig:
        for line in mig:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-gui-cgsshape.")

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8" and build == "10K549":
            required_arch = "ppc7400"
            required_inner = "__CGSWindowShape"
            forbidden_inner = None
        elif product == "10.7.5" and build == "11G63":
            required_arch = "i386"
            required_inner = "__CGSCopyWindowShape"
            forbidden_inner = None
        else:
            required_arch = None
            required_inner = None
            forbidden_inner = None
            issues.append("unsupported product/build: %s/%s" % (product, build))

        with open(report, "w") as fp:
            write_line(fp, "== PPC Carbon GUI CGSShapeWindow protocol differential audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" %
                       (required_arch if required_arch else "UNSUPPORTED"))
            write_line(fp, "legacy_live_request_id=0x%08x" % LEGACY_REQUEST_ID)
            write_line(fp, "legacy_live_reply_id=0x%08x" % LEGACY_REPLY_ID)
            write_line(fp, "required_inner_shape_helper=%s" %
                       (required_inner if required_inner else "UNSUPPORTED"))

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())
            cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== CoreGraphics ==")
            write_line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                write_line(fp, "state=MISSING")
                issues.append("CoreGraphics binary missing")
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
                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        write_line(fp, "nm_failed")
                        issues.append("nm failed")
                    else:
                        symbols = parse_symbols(nm_out)
                        write_line(fp, "parsed_text_symbols=%d" % len(symbols))

                        target_indexes = [i for i, item in enumerate(symbols)
                                          if target_symbol(item[1])]
                        write_line(fp)
                        write_line(fp, "== shape-family symbol inventory ==")
                        write_line(fp, "shape_family_symbol_count=%d" %
                                   len(target_indexes))
                        for i in target_indexes:
                            write_line(fp, "%s@0x%x" %
                                       (symbols[i][1], symbols[i][0]))

                        names = [symbols[i][1] for i in target_indexes]
                        if not any(name == "_CGSShapeWindow" for name in names):
                            issues.append("_CGSShapeWindow symbol missing")
                        if required_inner is not None and required_inner not in names:
                            issues.append("required inner shape helper missing: %s" %
                                          required_inner)
                        if forbidden_inner is not None and forbidden_inner in names:
                            issues.append("unexpected inner shape helper present: %s" %
                                          forbidden_inner)

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                        if rc != 0:
                            write_line(fp, "otool_disassembly_failed")
                            issues.append("otool disassembly failed")
                        else:
                            rows = parse_instructions(dis_out)
                            groups = group_rows_by_symbol(rows, symbols)
                            write_line(fp, "parsed_instruction_lines=%d" % len(rows))

                            write_line(fp)
                            write_line(fp, "== legacy live ID anchor inventory ==")
                            request_hits = []
                            reply_hits = []
                            for i, selected in groups.items():
                                ids = candidate_ids(selected)
                                if LEGACY_REQUEST_ID in ids:
                                    request_hits.append(i)
                                if LEGACY_REPLY_ID in ids:
                                    reply_hits.append(i)
                            write_line(fp, "legacy_request_anchor_symbol_count=%d" %
                                       len(request_hits))
                            for i in request_hits:
                                write_line(fp, "request_anchor_symbol=%s@0x%x" %
                                           (symbols[i][1], symbols[i][0]))
                            write_line(fp, "legacy_reply_anchor_symbol_count=%d" %
                                       len(reply_hits))
                            for i in reply_hits:
                                write_line(fp, "reply_anchor_symbol=%s@0x%x" %
                                           (symbols[i][1], symbols[i][0]))

                            outer_indexes = [i for i, item in enumerate(symbols)
                                             if item[1] == "_CGSShapeWindow"]
                            write_line(fp)
                            write_line(fp, "== outer shape helper linkage ==")
                            outer_mentions_required = False
                            for i in outer_indexes:
                                selected = groups.get(i, [])
                                write_line(fp, "_CGSShapeWindow@0x%x" %
                                           symbols[i][0])
                                for addr, line in selected:
                                    if required_inner is not None and required_inner in line:
                                        outer_mentions_required = True
                                        write_line(fp, "required_inner_call=%s" % line)
                                    elif ("CGSWindowShape" in line or
                                          "CGSCopyWindowShape" in line or
                                          "CGSSetWindowShape" in line or
                                          "CGSShapeWindow" in line):
                                        write_line(fp, "shape_call=%s" % line)
                            write_line(fp, "outer_calls_required_inner=%s" %
                                       ("YES" if outer_mentions_required else "NO"))
                            if required_inner is not None and not outer_mentions_required:
                                issues.append("_CGSShapeWindow does not reference required inner helper: %s" %
                                              required_inner)

                            write_line(fp)
                            write_line(fp, "== shape-family detailed windows ==")
                            for i in target_indexes:
                                emit_symbol(fp, symbols, i, groups)

                            write_line(fp)
                            write_line(fp, "== nearby generated-MIG candidates ==")
                            candidate_indexes = []
                            for i, selected in groups.items():
                                if i in target_indexes:
                                    continue
                                if not any("mach_msg" in line for addr, line in selected):
                                    continue
                                ids = candidate_ids(selected)
                                if not ids:
                                    continue
                                name = symbols[i][1]
                                if ("Window" in name or "Shape" in name or
                                    "CGS" in name):
                                    candidate_indexes.append(i)
                            write_line(fp, "nearby_candidate_count=%d" %
                                       len(candidate_indexes))
                            for i in candidate_indexes[:80]:
                                ids = candidate_ids(groups.get(i, []))
                                write_line(fp, "%s@0x%x ids=%s" %
                                           (symbols[i][1], symbols[i][0],
                                            ",".join("0x%08x" % value
                                                     for value in ids)))
                            if len(candidate_indexes) > 80:
                                write_line(fp, "additional_candidates_omitted=%d" %
                                           (len(candidate_indexes) - 80))

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
            write_line(fp, "No CGS, CPS, bootstrap, Mach, WindowServer, or display request was issued by this audit.")
            write_line(fp, "No CoreGraphics, WindowServer, Rosetta, dyld, cache, launchd, or XNU state was modified by this audit.")
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
