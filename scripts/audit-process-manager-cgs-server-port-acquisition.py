#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-cgs-server-port-acquisition.txt"
ANALYZER_VERSION = "2"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

ARCHES = ["i386", "x86_64", "ppc7400"]

TARGET_RE = re.compile(
    r"(CGSServerPort|lookupServerPort|CGSLookupSessionPort|getSessionPort|CGSLookupServerRootPort|"
    r"CGSessionGetWindowServerPort|CGSSessionDeathWatchPort|"
    r"CGX(?:Active|Root|WindowServer|Enable).*WindowServerPort|"
    r"current_session_set_bootstrap_port|CGSLookupServerPort|"
    r"CGWindowServerCFMachPort|CGSNewConnectionPort|CGSNewConnection|"
    r"CGSDefaultConnection|CGSInitialize)",
    re.I,
)

IMPORT_RE = re.compile(
    r"(bootstrap_|vproc_|xpc_|mach_msg|mach_port_|audit|session|windowserver)",
    re.I,
)

STRING_RE = re.compile(
    r"(WindowServer|windowserver|bootstrap|session|CGSNewConnection|"
    r"CGSLookupServerPort|on-demand launch|CGError|com\.apple\.)",
    re.I,
)

BASE_REQUIRED = [
    "_CGSLookupServerPort",
    "_CGSNewConnection",
    "__CGSNewConnectionPort",
    "__CGSDefaultConnection",
    "_CGSServerPort",
    "_lookupServerPort",
    "_CGSLookupServerRootPort",
]

SNOW_HELPER_EVIDENCE = [
    "_CGSLookupSessionPort",
]

LION_HELPER_EVIDENCE = [
    "_getSessionPort",
    "__CGSGetSessionPort",
    "_CGSessionGetWindowServerPort",
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


def write_line(fp, text=""):
    fp.write(text)
    fp.write("\n")


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
    by_name = {}
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
        if is_text:
            by_name.setdefault(name, []).append(addr)
    ordered.sort()
    return ordered, by_name


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


def emit_symbol_window(fp, rows, ordered_text, name, start, max_bytes=0x5000):
    write_line(fp)
    write_line(fp, "-- symbol window: %s --" % name)
    write_line(fp, "symbol_address=0x%x" % start)

    end = start + max_bytes
    nxt = next_symbol_address(ordered_text, start)
    if nxt is not None:
        end = min(end, nxt)

    count = 0
    for addr, line in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        write_line(fp, line)
        count += 1
    write_line(fp, "instruction_lines=%d" % count)


def emit_references(fp, dis_lines, name, address, duplicate_count):
    write_line(fp)
    write_line(fp, "-- references to %s @ 0x%x --" % (name, address))
    if duplicate_count > 1:
        write_line(fp, "duplicate_symbol_name_count=%d" % duplicate_count)
        write_line(fp, "reference_scope=name-wide; correlate each call with the emitted same-name windows")
    refs = []
    forms = [
        "0x%x" % address,
        "%08x" % address,
        "%016x" % address,
    ]
    for line in dis_lines:
        if name in line:
            refs.append(line)
            continue
        if ("call" in line or "\tbl\t" in line or "\tb\t" in line or
                "\tbctr" in line or "\tjmp" in line):
            for form in forms:
                if form in line:
                    refs.append(line)
                    break
    write_line(fp, "reference_lines=%d" % len(refs))
    for line in refs[:300]:
        write_line(fp, line)
    if len(refs) > 300:
        write_line(fp, "additional_reference_lines_omitted=%d" %
                   (len(refs) - 300))


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
    write_line(fp, "cache_map_path=%s" % COREGRAPHICS)
    write_line(fp, "cache_map_contains=%s" % ("YES" if matches else "NO"))
    for line in matches[:8]:
        write_line(fp, line)


def emit_focused_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "-- addressed focused cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "otool_cstring_dump_failed")
        write_line(fp, out.rstrip())
        return
    hits = [line for line in out.splitlines() if STRING_RE.search(line)]
    for line in hits[:500]:
        write_line(fp, line)
    if len(hits) > 500:
        write_line(fp, "additional_cstring_hits_omitted=%d" %
                   (len(hits) - 500))


def analyze_slice(fp, product, path, arch, tempdir, issues, evidence):
    thin = os.path.join(tempdir, "CoreGraphics.%s" % arch)
    ok, out = thin_arch(path, arch, thin)

    write_line(fp)
    write_line(fp, "== CoreGraphics slice: %s ==" % arch)
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        if product == "10.6.8" and arch == "ppc7400":
            issues.append("CoreGraphics/ppc7400: required Snow Leopard PPC slice missing")
        if product == "10.7.5" and arch == "i386":
            issues.append("CoreGraphics/i386: required Lion i386 slice missing")
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
    write_line(fp, "-- focused strings --")
    if rc == 0:
        hits = [line for line in strings_out.splitlines()
                if STRING_RE.search(line)]
        for line in hits[:500]:
            write_line(fp, line)
        if len(hits) > 500:
            write_line(fp, "additional_string_hits_omitted=%d" %
                       (len(hits) - 500))
    else:
        write_line(fp, "strings_failed")

    emit_focused_cstrings(fp, thin)

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "-- nm failed --")
        write_line(fp, nm_out.rstrip())
        issues.append("CoreGraphics/%s: nm failed" % arch)
        return

    write_line(fp, "-- focused symbols/imports --")
    nm_hits = [line for line in nm_out.splitlines()
               if TARGET_RE.search(line) or IMPORT_RE.search(line)]
    for line in nm_hits[:1200]:
        write_line(fp, line)
    if len(nm_hits) > 1200:
        write_line(fp, "additional_nm_hits_omitted=%d" %
                   (len(nm_hits) - 1200))

    ordered, by_name = parse_symbols(nm_out)
    ordered_text = text_symbols(ordered)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "-- disassembly failed --")
        write_line(fp, dis_out.rstrip())
        issues.append("CoreGraphics/%s: otool disassembly failed" % arch)
        return

    rows = parse_instructions(dis_out)
    dis_lines = dis_out.splitlines()

    selected = []
    for name, addrs in by_name.items():
        if TARGET_RE.search(name):
            for addr in addrs:
                selected.append((addr, name))
    selected.sort()

    write_line(fp, "parsed_text_symbols=%d" % len(ordered_text))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_symbol_windows=%d" % len(selected))

    for name in BASE_REQUIRED:
        if by_name.get(name):
            evidence[(arch, name)] = True

    for name in SNOW_HELPER_EVIDENCE + LION_HELPER_EVIDENCE:
        if by_name.get(name) or name in dis_out:
            evidence[(arch, name)] = True

    write_line(fp)
    write_line(fp, "-- duplicate target symbols --")
    duplicates = []
    for name, addrs in by_name.items():
        if TARGET_RE.search(name) and len(addrs) > 1:
            duplicates.append((name, sorted(addrs)))
    duplicates.sort()
    if not duplicates:
        write_line(fp, "NONE")
    for name, addrs in duplicates:
        write_line(fp, "%s count=%d addresses=%s" %
                   (name, len(addrs), ",".join("0x%x" % addr for addr in addrs)))

    write_line(fp)
    write_line(fp, "-- focused helper call/reference lines --")
    helper_hits = [line for line in dis_lines
                   if TARGET_RE.search(line) or IMPORT_RE.search(line)]
    for line in helper_hits[:1400]:
        write_line(fp, line)
    if len(helper_hits) > 1400:
        write_line(fp, "additional_helper_lines_omitted=%d" %
                   (len(helper_hits) - 1400))

    for addr, name in selected:
        emit_symbol_window(fp, rows, ordered_text, name, addr)
        emit_references(fp, dis_lines, name, addr, len(by_name.get(name, [])))


def validate_evidence(product, evidence, issues):
    required_arch = "ppc7400" if product == "10.6.8" else "i386"
    for name in BASE_REQUIRED:
        if not evidence.get((required_arch, name), False):
            issues.append("%s/%s: required target missing: %s" %
                          (product, required_arch, name))

    if product == "10.6.8":
        for name in SNOW_HELPER_EVIDENCE:
            visible = (evidence.get(("ppc7400", name), False) or
                       evidence.get(("i386", name), False) or
                       evidence.get(("x86_64", name), False))
            if not visible:
                issues.append("10.6.8: required Snow server-port helper evidence missing: %s" % name)
    elif product == "10.7.5":
        for name in LION_HELPER_EVIDENCE:
            visible = (evidence.get(("i386", name), False) or
                       evidence.get(("x86_64", name), False))
            if not visible:
                issues.append("10.7.5: required Lion server-port helper evidence missing: %s" % name)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-cgs-server-port.")
    issues = []
    evidence = {}

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager CGS server-port acquisition audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== CoreGraphics ==")
            write_line(fp, "path=%s" % COREGRAPHICS)

            if not os.path.isfile(COREGRAPHICS):
                write_line(fp, "state=MISSING")
                issues.append("CoreGraphics binary missing")
            else:
                write_line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                rc, out = run(["/usr/bin/file", COREGRAPHICS])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREGRAPHICS])
                write_line(fp, out.rstrip())

                for arch in ARCHES:
                    analyze_slice(fp, product, COREGRAPHICS, arch,
                                  tempdir, issues, evidence)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if product not in ("10.6.8", "10.7.5"):
                issues.append("unsupported product version: %s" % product)
            else:
                validate_evidence(product, evidence, issues)

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No CoreGraphics, WindowServer, bootstrap, launchd, or session state was modified by this audit.")
            write_line(fp, "No Mach request was sent by this audit.")
            write_line(fp, "No launchd job or service was started, stopped, restarted, or signaled.")
            write_line(fp, "No system file was modified by this audit.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        print("No PowerPC application was launched and no system file was modified.")
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
