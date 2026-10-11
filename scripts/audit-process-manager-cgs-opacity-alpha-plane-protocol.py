#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-cgs-opacity-alpha-plane-protocol.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

TARGETS = [
    "_CGSSetWindowOpacity",
    "__CGSCreateWindowAlphaPlane",
    "__CGSTerminateWindowAlphaPlane",
]

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

def parse_symbols(text):
    ordered = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        is_text = "(__TEXT,__text)" in line
        ordered.append((addr, name, line, is_text))
    ordered.sort()
    return ordered

def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        rows.append((addr, line))
    return rows

def text_symbols(ordered):
    return [(addr, name) for addr, name, line, is_text in ordered if is_text]

def next_symbol_address(ordered_text, start):
    for addr, name in ordered_text:
        if addr > start:
            return addr
    return None

def symbol_window_rows(rows, ordered_text, start, max_bytes=0x4000):
    end = start + max_bytes
    nxt = next_symbol_address(ordered_text, start)
    if nxt is not None:
        end = min(end, nxt)
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]

def exact_symbol(ordered, target):
    hits = []
    for addr, name, line, is_text in ordered:
        if is_text and name == target:
            hits.append((addr, name))
    return hits

def emit_target(fp, rows, ordered_text, target, start):
    selected = symbol_window_rows(rows, ordered_text, start)
    write_line(fp)
    write_line(fp, "== target: %s ==" % target)
    write_line(fp, "symbol_address=0x%x" % start)
    write_line(fp, "instruction_lines=%d" % len(selected))

    write_line(fp, "-- full symbol window --")
    for addr, line in selected:
        write_line(fp, line)

    write_line(fp, "-- direct calls/branches --")
    calls = []
    for addr, line in selected:
        lower = line.lower()
        if ("\tcall" in lower or "\tbl\t" in lower or
                "\tb\t" in lower or "\tjmp" in lower):
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

    write_line(fp, "-- immediate-bearing lines --")
    immediates = [line for addr, line in selected if "0x" in line]
    if immediates:
        for line in immediates:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    return selected

def cache_provenance(fp):
    write_line(fp)
    write_line(fp, "== Rosetta shared-cache provenance ==")
    if os.path.isfile(ROSETTA_CACHE):
        write_line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
    else:
        write_line(fp, "rosetta_cache=MISSING")
    if not os.path.isfile(ROSETTA_MAP):
        write_line(fp, "rosetta_cache_map=MISSING")
        return
    write_line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
    try:
        data = open(ROSETTA_MAP, "r").read()
    except IOError as e:
        write_line(fp, "rosetta_cache_map_read_error=%s" % e)
        return
    matches = [line for line in data.splitlines() if COREGRAPHICS in line]
    write_line(fp, "cache_map_contains_coregraphics=%s" %
               ("YES" if matches else "NO"))
    for line in matches[:8]:
        write_line(fp, line)

def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-cgs-opacity-alpha.")
    issues = []

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8":
            arch = "ppc7400"
        elif product == "10.7.5":
            arch = "i386"
        else:
            arch = None
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager CGS opacity alpha-plane protocol audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (arch if arch else "NONE"))

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())
            cache_provenance(fp)

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
                rc, out = run(["/usr/bin/lipo", COREGRAPHICS, "-thin", arch,
                               "-output", thin])
                if rc != 0:
                    rc, out = run(["/usr/bin/lipo", "-thin", arch,
                                   COREGRAPHICS, "-output", thin])
                if rc != 0:
                    write_line(fp, "thin=NO")
                    write_line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing: %s" % arch)
                else:
                    write_line(fp, "thin=YES")
                    write_line(fp, "slice_sha256=%s" % sha256(thin))

                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        write_line(fp, "nm=FAIL")
                        write_line(fp, nm_out.rstrip())
                        issues.append("nm failed")
                    else:
                        ordered = parse_symbols(nm_out)
                        ordered_text = text_symbols(ordered)

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                        if rc != 0:
                            write_line(fp, "disassembly=FAIL")
                            write_line(fp, dis_out.rstrip())
                            issues.append("otool disassembly failed")
                        else:
                            rows = parse_instructions(dis_out)
                            write_line(fp, "parsed_text_symbols=%d" %
                                       len(ordered_text))
                            write_line(fp, "parsed_instruction_lines=%d" %
                                       len(rows))

                            windows = {}
                            write_line(fp)
                            write_line(fp, "== Target inventory ==")
                            for target in TARGETS:
                                hits = exact_symbol(ordered, target)
                                write_line(fp, "%s count=%d%s" %
                                           (target, len(hits),
                                            (" addresses=%s" %
                                             ",".join("0x%x" % x[0] for x in hits))
                                             if hits else "")))
                                if len(hits) != 1:
                                    issues.append("%s: expected exactly one text symbol" %
                                                  target)
                                elif target not in windows:
                                    windows[target] = emit_target(
                                        fp, rows, ordered_text, target, hits[0][0])

                            wrapper = windows.get("_CGSSetWindowOpacity", [])
                            wrapper_text = "\n".join(line for addr, line in wrapper)
                            create_window = windows.get(
                                "__CGSCreateWindowAlphaPlane", [])
                            create_text = "\n".join(
                                line for addr, line in create_window)
                            terminate_window = windows.get(
                                "__CGSTerminateWindowAlphaPlane", [])
                            terminate_text = "\n".join(
                                line for addr, line in terminate_window)

                            write_line(fp)
                            write_line(fp, "== Structural validation ==")
                            wrapper_create = (
                                "__CGSCreateWindowAlphaPlane" in wrapper_text)
                            wrapper_terminate = (
                                "__CGSTerminateWindowAlphaPlane" in wrapper_text)
                            create_mach = "_mach_msg" in create_text
                            terminate_mach = "_mach_msg" in terminate_text
                            create_reply = "mig_get_reply_port" in create_text
                            terminate_reply = "mig_get_reply_port" in terminate_text

                            write_line(fp, "wrapper_calls_create_alpha_plane=%s" %
                                       ("YES" if wrapper_create else "NO"))
                            write_line(fp, "wrapper_calls_terminate_alpha_plane=%s" %
                                       ("YES" if wrapper_terminate else "NO"))
                            write_line(fp, "create_alpha_plane_calls_mach_msg=%s" %
                                       ("YES" if create_mach else "NO"))
                            write_line(fp, "create_alpha_plane_gets_reply_port=%s" %
                                       ("YES" if create_reply else "NO"))
                            write_line(fp, "terminate_alpha_plane_calls_mach_msg=%s" %
                                       ("YES" if terminate_mach else "NO"))
                            write_line(fp, "terminate_alpha_plane_gets_reply_port=%s" %
                                       ("YES" if terminate_reply else "NO"))

                            if not wrapper_create:
                                issues.append(
                                    "CGSSetWindowOpacity does not directly call create alpha-plane helper")
                            if not wrapper_terminate:
                                issues.append(
                                    "CGSSetWindowOpacity does not directly call terminate alpha-plane helper")
                            if not create_mach or not create_reply:
                                issues.append(
                                    "create alpha-plane helper is not a direct generated-MIG client")
                            if not terminate_mach or not terminate_reply:
                                issues.append(
                                    "terminate alpha-plane helper is not a direct generated-MIG client")

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
            write_line(fp, "No CreateNewWindow, CGS, CPS, bootstrap, Mach, or WindowServer request was issued by this audit.")
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
