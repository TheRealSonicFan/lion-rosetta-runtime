#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-cgs-default-connection.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

HISERVICES = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CACHE_PATHS = [
    HISERVICES,
    COREGRAPHICS,
]

BINARIES = [
    ("HIServices", HISERVICES, ["i386", "x86_64", "ppc7400"]),
    ("CoreGraphics", COREGRAPHICS, ["i386", "x86_64", "ppc7400"]),
]

EXACT_TARGETS = {
    "HIServices": [
        "__RegisterApplication",
        "_RegisterApplication",
        "_RegisterCGSessionWhenFirstRootProcessLaunches",
        "_TransformProcessType",
        "_SetFrontProcessWithOptions",
    ],
    "CoreGraphics": [
        "_CGSInitialize",
        "__CGSConnectionInitialize",
        "_CGSDefaultConnectionForThread",
        "__CGSDefaultConnection",
        "_CGSMainConnectionID",
        "__CGSMainConnection",
        "_CGSDefaultConnectionMachPort",
        "_CGSNewConnection",
        "__CGSNewConnectionPort",
        "_CGSLookupServerPort",
        "_CGWindowServerCFMachPort",
        "__CPSInitialize",
        "__CPSRegisterWithServer",
        "__CGSCheckInApplication",
        "_CGSGetDenyWindowServerConnections",
        "_CGSSetDenyWindowServerConnections",
    ],
}

REQUIRED_TARGETS = {
    "HIServices": [
        "__RegisterApplication",
    ],
    "CoreGraphics": [
        "_CGSInitialize",
        "__CGSDefaultConnection",
        "_CGSNewConnection",
        "__CGSNewConnectionPort",
        "_CGSLookupServerPort",
        "__CPSRegisterWithServer",
    ],
}

FOCUS_RE = re.compile(
    r"(RegisterApplication|CGSInitialize|CGSConnectionInitialize|"
    r"CGSDefaultConnection|CGSMainConnection|CGSNewConnection|"
    r"CGSLookupServerPort|CGWindowServerCFMachPort|CPSInitialize|"
    r"CPSRegisterWithServer|CGSCheckInApplication|DenyWindowServer|"
    r"WindowServer|windowserver|bootstrap_|vproc_|xpc_|mach_msg|"
    r"CGError|on-demand launch|com\.apple\.(?:windowserver|WindowServer))",
    re.I,
)

PROCESS_RE = re.compile(
    r"(WindowServer|windowserver|loginwindow|Dock|coreservicesd|pbs)",
    re.I,
)


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
            by_name[name] = addr
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


def emit_symbol_window(fp, rows, ordered_text, name, start, max_bytes=0x6000):
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


def emit_references(fp, dis_lines, name, address):
    write_line(fp)
    write_line(fp, "-- references to %s --" % name)
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

    for path in CACHE_PATHS:
        matches = [line for line in data.splitlines() if path in line]
        write_line(fp, "cache_map_path=%s" % path)
        write_line(fp, "cache_map_contains=%s" %
                   ("YES" if matches else "NO"))
        for line in matches[:8]:
            write_line(fp, line)


def runtime_service_state(fp):
    write_line(fp)
    write_line(fp, "== Read-only WindowServer/service state ==")

    rc, out = run(["/bin/ps", "ax", "-o", "pid=,ppid=,uid=,command="])
    write_line(fp, "-- matching processes --")
    if rc == 0:
        hits = [line for line in out.splitlines() if PROCESS_RE.search(line)]
        if hits:
            for line in hits:
                write_line(fp, line)
        else:
            write_line(fp, "(none)")
    else:
        write_line(fp, "ps_failed")
        write_line(fp, out.rstrip())

    if os.path.exists("/bin/launchctl"):
        rc, out = run(["/bin/launchctl", "list"])
        write_line(fp, "-- matching launchctl jobs --")
        if rc == 0:
            hits = [line for line in out.splitlines()
                    if PROCESS_RE.search(line)]
            if hits:
                for line in hits:
                    write_line(fp, line)
            else:
                write_line(fp, "(none)")
        else:
            write_line(fp, "launchctl_list_failed")
            write_line(fp, out.rstrip())


def analyze_slice(fp, product, label, path, arch, tempdir, issues):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
    ok, out = thin_arch(path, arch, thin)

    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        if product == "10.6.8" and arch == "ppc7400":
            issues.append("%s/%s: required Snow Leopard PPC slice missing" %
                          (label, arch))
        if product == "10.7.5" and arch == "i386":
            issues.append("%s/%s: required Lion i386 slice missing" %
                          (label, arch))
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
    write_line(fp, "-- focused strings --")
    if rc == 0:
        hits = [line for line in strings_out.splitlines()
                if FOCUS_RE.search(line)]
        for line in hits[:500]:
            write_line(fp, line)
        if len(hits) > 500:
            write_line(fp, "additional_string_hits_omitted=%d" %
                       (len(hits) - 500))
    else:
        write_line(fp, "strings_failed")

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "-- nm failed --")
        write_line(fp, nm_out.rstrip())
        issues.append("%s/%s: nm failed" % (label, arch))
        return

    write_line(fp, "-- focused symbols/imports --")
    nm_hits = [line for line in nm_out.splitlines()
               if FOCUS_RE.search(line)]
    for line in nm_hits[:900]:
        write_line(fp, line)
    if len(nm_hits) > 900:
        write_line(fp, "additional_nm_hits_omitted=%d" %
                   (len(nm_hits) - 900))

    ordered, by_name = parse_symbols(nm_out)
    ordered_text = text_symbols(ordered)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "-- disassembly failed --")
        write_line(fp, dis_out.rstrip())
        issues.append("%s/%s: otool disassembly failed" % (label, arch))
        return

    rows = parse_instructions(dis_out)
    dis_lines = dis_out.splitlines()

    selected = []
    for name in EXACT_TARGETS.get(label, []):
        if name in by_name:
            selected.append((name, by_name[name]))

    write_line(fp, "parsed_text_symbols=%d" % len(ordered_text))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "exact_target_windows=%d" % len(selected))

    required_missing = []
    for name in REQUIRED_TARGETS.get(label, []):
        if name not in by_name:
            required_missing.append(name)

    if required_missing:
        write_line(fp, "required_targets_missing=%s" %
                   ",".join(required_missing))
        if product == "10.6.8" and arch == "ppc7400":
            issues.append("%s/%s: required targets missing: %s" %
                          (label, arch, ",".join(required_missing)))
        if product == "10.7.5" and arch == "i386":
            issues.append("%s/%s: required targets missing: %s" %
                          (label, arch, ",".join(required_missing)))
    else:
        write_line(fp, "required_targets_missing=NONE")

    for name, addr in selected:
        emit_symbol_window(fp, rows, ordered_text, name, addr)
        emit_references(fp, dis_lines, name, addr)


def analyze_binary(fp, product, label, path, arches, tempdir, issues):
    write_line(fp)
    write_line(fp, "============================================================")
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)

    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        issues.append("%s: binary missing" % label)
        return

    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    write_line(fp, out.rstrip())

    for arch in arches:
        analyze_slice(fp, product, label, path, arch, tempdir, issues)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-cgs-default-connection.")
    issues = []

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager CGS default-connection audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)

            rc, out = run(
                ["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            cache_provenance(fp)
            runtime_service_state(fp)

            for label, path, arches in BINARIES:
                analyze_binary(fp, product, label, path, arches,
                               tempdir, issues)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if product not in ("10.6.8", "10.7.5"):
                issues.append("unsupported product version: %s" % product)

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No WindowServer/default-connection/CPS/CGS state was modified by this audit.")
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
