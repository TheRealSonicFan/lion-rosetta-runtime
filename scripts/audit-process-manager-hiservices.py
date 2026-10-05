#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-hiservices-audit.txt"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

BINARIES = [
    ("HIServices",
     "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"),
    ("ApplicationServices",
     "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/ApplicationServices"),
    ("CarbonCore",
     "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"),
    ("AE",
     "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/AE"),
    ("RosettaApplicationServicesShim",
     "/usr/libexec/oah/Shims/ApplicationServices.framework/Versions/A/ApplicationServices"),
    ("RosettaInterposers",
     "/usr/libexec/oah/Shims/Interposers.dylib"),
]

CACHE_PATHS = [
    "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices",
    "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/ApplicationServices",
    "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore",
    "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/AE",
]

TARGET_SYMBOLS = [
    "_GetCurrentProcess",
    "_GetProcessPID",
    "_GetProcessForPID",
    "_TransformProcessType",
    "_SetFrontProcess",
    "_SetFrontProcessWithOptions",
    "_GetFrontProcess",
    "_SameProcess",
    "_GetProcessInformation",
]

FILTER_RE = re.compile(
    r"(GetCurrentProcess|GetProcessPID|GetProcessForPID|TransformProcessType|"
    r"SetFrontProcess|ProcessSerial|Process Manager|ProcessManager|"
    r"\bPSN\b|\bCPS[A-Za-z0-9_]*|ApplicationASN|ASN|pbs|"
    r"coreservicesd|launchservices|WindowServer|CGS|Rosetta|OAH)",
    re.I,
)

PROCESS_RE = re.compile(
    r"(pbs|coreservicesd|launchservices|lsd|WindowServer|loginwindow|Dock)",
    re.I,
)

NM_RE = re.compile(r"^\s*([0-9A-Fa-f]+)\s+.*\s(\S+)$")
INSN_RE = re.compile(r"^\s*([0-9A-Fa-f]+)\s+(.*)$")


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
    if rc != 0:
        rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0, out


def thin_arch(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out


def parse_symbols(text):
    symbols = {}
    ordered = []
    for line in text.splitlines():
        m = NM_RE.match(line)
        if not m:
            continue
        try:
            addr = int(m.group(1), 16)
        except ValueError:
            continue
        name = m.group(2)
        symbols[name] = addr
        ordered.append((addr, name))
    ordered.sort()
    return symbols, ordered


def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        m = INSN_RE.match(line)
        if not m:
            continue
        try:
            addr = int(m.group(1), 16)
        except ValueError:
            continue
        rows.append((addr, line))
    return rows


def next_symbol_address(ordered, start):
    for addr, name in ordered:
        if addr > start:
            return addr
    return None


def emit_symbol_window(fp, rows, ordered, name, start, max_bytes=0x500):
    write_line(fp)
    write_line(fp, "-- symbol window: %s --" % name)
    write_line(fp, "symbol_address=0x%x" % start)

    end = start + max_bytes
    nxt = next_symbol_address(ordered, start)
    if nxt is not None:
        end = min(end, nxt)

    emitted = 0
    for addr, line in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        write_line(fp, line)
        emitted += 1
    write_line(fp, "instruction_lines=%d" % emitted)


def map_membership(fp):
    write_line(fp)
    write_line(fp, "== Rosetta shared-cache provenance ==")
    if os.path.isfile(ROSETTA_CACHE):
        write_line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
        rc, out = run(["/usr/bin/file", ROSETTA_CACHE])
        write_line(fp, out.rstrip())
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
        write_line(fp)
        write_line(fp, "cache_map_path=%s" % path)
        write_line(fp, "cache_map_contains=%s" % ("YES" if matches else "NO"))
        for line in matches[:12]:
            write_line(fp, line)
        if len(matches) > 12:
            write_line(fp, "additional_map_lines_omitted=%d" % (len(matches) - 12))


def helper_state(fp):
    write_line(fp)
    write_line(fp, "== Process/session helper state ==")

    rc, out = run(["/bin/ps", "ax", "-o", "pid=,ppid=,command="])
    if rc == 0:
        hits = [line for line in out.splitlines() if PROCESS_RE.search(line)]
        write_line(fp, "-- matching processes --")
        for line in hits:
            write_line(fp, line)
        if not hits:
            write_line(fp, "(none)")
    else:
        write_line(fp, "ps_failed")
        write_line(fp, out.rstrip())

    if os.path.exists("/bin/launchctl"):
        rc, out = run(["/bin/launchctl", "list"])
        write_line(fp, "-- matching launchd jobs --")
        if rc == 0:
            hits = [line for line in out.splitlines() if PROCESS_RE.search(line)]
            for line in hits:
                write_line(fp, line)
            if not hits:
                write_line(fp, "(none)")
        else:
            write_line(fp, "launchctl_list_failed")
            write_line(fp, out.rstrip())


def analyze_slice(fp, label, path, arch, tempdir):
    safe_label = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe_label, arch))
    ok, out = thin_arch(path, arch, thin)
    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        write_line(fp, out.rstrip())
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
    write_line(fp, "-- filtered strings --")
    if rc == 0:
        hits = [line for line in strings_out.splitlines() if FILTER_RE.search(line)]
        for line in hits[:400]:
            write_line(fp, line)
        if len(hits) > 400:
            write_line(fp, "additional_string_hits_omitted=%d" % (len(hits) - 400))
    else:
        write_line(fp, "strings_failed")

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    write_line(fp, "-- filtered symbols/imports --")
    if rc != 0:
        write_line(fp, "nm_failed")
        write_line(fp, nm_out.rstrip())
        return

    nm_hits = [line for line in nm_out.splitlines() if FILTER_RE.search(line)]
    for line in nm_hits[:500]:
        write_line(fp, line)
    if len(nm_hits) > 500:
        write_line(fp, "additional_nm_hits_omitted=%d" % (len(nm_hits) - 500))

    symbols, ordered = parse_symbols(nm_out)
    selected = []
    for name in TARGET_SYMBOLS:
        if name in symbols:
            selected.append((name, symbols[name]))

    for addr, name in ordered:
        if name in symbols and FILTER_RE.search(name):
            if (name, addr) not in selected:
                selected.append((name, addr))
        if len(selected) >= 40:
            break

    write_line(fp, "target_symbol_windows=%d" % len(selected))
    if not selected:
        return

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "otool_disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return

    rows = parse_instructions(dis_out)
    for name, addr in selected:
        emit_symbol_window(fp, rows, ordered, name, addr)


def analyze_binary(fp, label, path, tempdir):
    write_line(fp)
    write_line(fp, "============================================================")
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)

    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        return

    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())

    rc, out = run(["/usr/bin/lipo", "-info", path])
    write_line(fp, out.rstrip())

    attempted = set()
    for arch in ["i386", "ppc7400", "ppc"]:
        if arch in attempted:
            continue
        attempted.add(arch)
        analyze_slice(fp, label, path, arch, tempdir)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-hiservices-audit.")

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])

            write_line(fp, "== Process Manager / HIServices read-only audit ==")
            write_line(fp, "product_version=%s" % product.strip())
            write_line(fp, "build_version=%s" % build.strip())

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            map_membership(fp)
            helper_state(fp)

            for label, path in BINARIES:
                analyze_binary(fp, label, path, tempdir)

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No registration database was modified by this audit.")
            write_line(fp, "No system file was modified by this audit.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        print("No PowerPC application was launched and no system file was modified.")
        return 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
