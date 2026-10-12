#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-showwindow-color-profile-window-context.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

PRIMARY_SYMBOLS = [
    "_CGSColorProfileCreateWithColorProfileID",
    "__CGSColorProfileClient",
    "__CGSWindowColorProfile",
    "_CGWindowContextCreate",
]

SUPPORT_RE = re.compile(
    r"(CGSColorProfile|CGXColorProfile|XColorProfile|WindowColorProfile|"
    r"CGWindowContext|ColorTransform|ColorSpace|WindowServerPort|"
    r"CGXWindowServerPort|CGSConnection|CGSMainConnection|"
    r"bootstrap|mach_msg|mig_|ColorSync)",
    re.I,
)

STRING_RE = re.compile(
    r"(color profile|color transform|window context|WindowColorProfile|"
    r"ColorProfile|ColorTransform|CGWindowContext|WindowServer|"
    r"bootstrap|mach_msg|ColorSync)",
    re.I,
)

CALL_RE = re.compile(r"\b(bl|bla|call|calll|jmp|jmpl)\b", re.I)
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

def find_symbol_indices(symbols, name):
    return [i for i, item in enumerate(symbols) if item[1] == name]

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

def emit_dependencies(fp, thin):
    write_line(fp)
    write_line(fp, "== linked libraries ==")
    rc, out = run(["/usr/bin/otool", "-L", thin])
    if rc == 0:
        for line in out.splitlines():
            write_line(fp, line)
    else:
        write_line(fp, "otool_L_failed")

def emit_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "== focused cstrings ==")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "otool_cstring_dump_failed")
        return
    hits = [line for line in out.splitlines() if STRING_RE.search(line)]
    write_line(fp, "focused_cstring_hit_count=%d" % len(hits))
    for line in hits[:2400]:
        write_line(fp, line)
    if len(hits) > 2400:
        write_line(fp, "additional_cstring_hits_omitted=%d" % (len(hits) - 2400))

def emit_imports(fp, thin):
    write_line(fp)
    write_line(fp, "== focused undefined/imported symbols ==")
    rc, out = run(["/usr/bin/nm", "-m", thin])
    if rc != 0:
        write_line(fp, "nm_m_failed")
        return
    hits = []
    for line in out.splitlines():
        if "undefined" in line.lower() and SUPPORT_RE.search(line):
            hits.append(line)
    write_line(fp, "focused_import_count=%d" % len(hits))
    for line in hits:
        write_line(fp, line)

def emit_symbol_window(fp, symbols, groups, index):
    addr, name = symbols[index]
    rows = groups.get(index, [])
    write_line(fp)
    write_line(fp, "== symbol: %s ==" % name)
    write_line(fp, "symbol_address=0x%x" % addr)
    write_line(fp, "instruction_lines=%d" % len(rows))
    write_line(fp, "-- full symbol window --")
    for row_addr, line in rows:
        write_line(fp, line)

    write_line(fp, "-- call/branch lines --")
    calls = [line for row_addr, line in rows if CALL_RE.search(line)]
    if calls:
        for line in calls:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    write_line(fp, "-- transport/bootstrap/color-profile references --")
    refs = [line for row_addr, line in rows if SUPPORT_RE.search(line)]
    if refs:
        for line in refs:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    values = []
    for row_addr, line in rows:
        for token in HEX_RE.findall(line):
            try:
                value = int(token, 16)
            except ValueError:
                continue
            if 0x1000 <= value <= 0x10000:
                values.append(value)
    write_line(fp, "-- 0x1000..0x10000 immediates --")
    if values:
        write_line(fp, ",".join("0x%08x" % x for x in sorted(set(values))))
    else:
        write_line(fp, "NONE")

def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-showwindow-color-profile.")

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
            write_line(fp, "== Process Manager ShowWindow color-profile/window-context static audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" %
                       (required_arch if required_arch else "UNSUPPORTED"))
            write_line(fp, "live_boundary=SetFrontWindow adapter succeeded; ShowWindow still no-return")
            write_line(fp, "audit_scope=CoreGraphics color-profile/window-context client path only")
            write_line(fp, "live_adapter_changes=NONE")

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
                    emit_dependencies(fp, thin)
                    emit_cstrings(fp, thin)
                    emit_imports(fp, thin)

                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        issues.append("nm failed")
                        write_line(fp, "nm_failed")
                    else:
                        symbols = parse_symbols(nm_out)
                        write_line(fp)
                        write_line(fp, "== symbol inventory ==")
                        write_line(fp, "parsed_text_symbols=%d" % len(symbols))

                        primary_indices = []
                        for name in PRIMARY_SYMBOLS:
                            indices = find_symbol_indices(symbols, name)
                            write_line(fp, "%s_count=%d" % (name, len(indices)))
                            for i in indices:
                                write_line(fp, "%s@0x%x" % (symbols[i][1], symbols[i][0]))
                                primary_indices.append(i)
                            if not indices:
                                issues.append("primary symbol missing: %s" % name)

                        support_indices = []
                        for i, item in enumerate(symbols):
                            if SUPPORT_RE.search(item[1]):
                                support_indices.append(i)
                        write_line(fp, "support_symbol_count=%d" % len(support_indices))
                        for i in support_indices[:1200]:
                            write_line(fp, "%s@0x%x" % (symbols[i][1], symbols[i][0]))
                        if len(support_indices) > 1200:
                            write_line(fp, "additional_support_symbols_omitted=%d" %
                                       (len(support_indices) - 1200))

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                        if rc != 0:
                            issues.append("otool disassembly failed")
                            write_line(fp, "otool_disassembly_failed")
                        else:
                            rows = parse_instructions(dis_out)
                            groups = group_rows_by_symbol(rows, symbols)
                            write_line(fp)
                            write_line(fp, "parsed_instruction_lines=%d" % len(rows))

                            emit_indices = set(primary_indices)
                            for i in support_indices:
                                name = symbols[i][1]
                                if (name.startswith("_CGSColorProfile") or
                                    name.startswith("__CGSColorProfile") or
                                    name.startswith("__CGSWindowColorProfile") or
                                    name.startswith("_CGWindowContext") or
                                    name.startswith("_CGColorTransform")):
                                    emit_indices.add(i)

                            write_line(fp, "emitted_symbol_window_count=%d" % len(emit_indices))
                            for i in sorted(emit_indices):
                                emit_symbol_window(fp, symbols, groups, i)

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
            write_line(fp, "No ShowWindow, CGS, bootstrap, Mach, ColorSync, or WindowServer request was issued by this audit.")
            write_line(fp, "No CoreGraphics, WindowServer, Rosetta, dyld, launchd, cache, or XNU state was modified by this audit.")
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
