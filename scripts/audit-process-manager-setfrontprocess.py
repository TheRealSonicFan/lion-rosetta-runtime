#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-setfrontprocess-callpath.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

HISERVICES = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
LAUNCHSERVICES = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
APP_SERVICES_SHIM = "/usr/libexec/oah/Shims/ApplicationServices.framework/Versions/A/ApplicationServices"
INTERPOSERS = "/usr/libexec/oah/Shims/Interposers.dylib"
WINDOWSERVER = "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/CoreGraphics.framework/Resources/WindowServer"

CACHE_PATHS = [
    HISERVICES,
    COREGRAPHICS,
    LAUNCHSERVICES,
]

BINARIES = [
    ("HIServices", HISERVICES, ["i386", "ppc7400"]),
    ("CoreGraphics", COREGRAPHICS, ["i386", "x86_64", "ppc7400"]),
    ("LaunchServices", LAUNCHSERVICES, ["i386", "x86_64", "ppc7400"]),
    ("RosettaApplicationServicesShim", APP_SERVICES_SHIM, ["i386", "ppc7400"]),
    ("RosettaInterposers", INTERPOSERS, ["i386", "ppc7400"]),
    ("WindowServer", WINDOWSERVER, ["i386", "x86_64"]),
]

EXACT_TARGETS = {
    "HIServices": [
        "_SetFrontProcess",
        "_SetFrontProcessWithOptions",
        "_GetFrontProcess",
        "_TransformProcessType",
        "__RegisterApplication",
        "_RegisterApplication",
    ],
    "CoreGraphics": [],
    "LaunchServices": [
        "__LSGetCurrentApplicationASN",
        "__LSCopyCurrentApplicationASN",
        "__LSCopyApplicationInformation",
        "__LSCopyApplicationInformationItem",
    ],
    "RosettaApplicationServicesShim": [],
    "RosettaInterposers": [],
    "WindowServer": [],
}

SYMBOL_RE = re.compile(
    r"(SetFrontProcess|GetFrontProcess|TransformProcessType|RegisterApplication|"
    r"FrontProcess|SetFront|CPS|CGS|Connection|WindowServer|ApplicationASN|LSASN|"
    r"CopyApplicationInformation|ProcessSerial|ProcessManager)",
    re.I,
)

STRING_RE = re.compile(
    r"(SetFrontProcess|GetFrontProcess|TransformProcessType|FrontProcess|SetFront|"
    r"CPS|CGS|WindowServer|default connection|connection|Process Manager|"
    r"ProcessManager|ApplicationASN|LSASN|coreservicesd|pbs)",
    re.I,
)

PROCESS_RE = re.compile(r"(WindowServer|pbs|coreservicesd|loginwindow|Dock)", re.I)


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


def emit_references(fp, dis_lines, name, address):
    write_line(fp)
    write_line(fp, "-- references to %s --" % name)
    refs = []
    forms = ["0x%x" % address, "%08x" % address, "%016x" % address]
    for line in dis_lines:
        if name in line:
            refs.append(line)
            continue
        if "call" in line or "\tbl\t" in line or "\tb\t" in line:
            for form in forms:
                if form in line:
                    refs.append(line)
                    break
    write_line(fp, "reference_lines=%d" % len(refs))
    for line in refs[:200]:
        write_line(fp, line)
    if len(refs) > 200:
        write_line(fp, "additional_reference_lines_omitted=%d" % (len(refs) - 200))


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
        write_line(fp, "cache_map_contains=%s" % ("YES" if matches else "NO"))
        for line in matches[:8]:
            write_line(fp, line)


def helper_state(fp):
    write_line(fp)
    write_line(fp, "== Foreground/backend helper state ==")
    rc, out = run(["/bin/ps", "ax", "-o", "pid=,ppid=,command="])
    if rc == 0:
        hits = [line for line in out.splitlines() if PROCESS_RE.search(line)]
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


def analyze_slice(fp, label, path, arch, tempdir, issues):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
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
    write_line(fp, "-- foreground/CPS/CGS strings --")
    if rc == 0:
        hits = [x for x in strings_out.splitlines() if STRING_RE.search(x)]
        for line in hits[:500]:
            write_line(fp, line)
        if len(hits) > 500:
            write_line(fp, "additional_string_hits_omitted=%d" % (len(hits) - 500))
    else:
        write_line(fp, "strings_failed")

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "-- nm failed --")
        write_line(fp, nm_out.rstrip())
        if label == "HIServices":
            issues.append("%s/%s: nm failed" % (label, arch))
        return

    write_line(fp, "-- foreground/CPS/CGS symbols and imports --")
    nm_hits = [x for x in nm_out.splitlines() if SYMBOL_RE.search(x)]
    for line in nm_hits[:900]:
        write_line(fp, line)
    if len(nm_hits) > 900:
        write_line(fp, "additional_nm_hits_omitted=%d" % (len(nm_hits) - 900))

    ordered, by_name = parse_symbols(nm_out)
    ordered_text = text_symbols(ordered)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "-- disassembly failed --")
        write_line(fp, dis_out.rstrip())
        if label == "HIServices":
            issues.append("%s/%s: otool disassembly failed" % (label, arch))
        return

    rows = parse_instructions(dis_out)
    dis_lines = dis_out.splitlines()

    targets = []
    for name in EXACT_TARGETS.get(label, []):
        if name in by_name:
            targets.append((name, by_name[name]))

    for addr, name, line, is_text in ordered:
        if not is_text:
            continue
        if SYMBOL_RE.search(name):
            item = (name, addr)
            if item not in targets:
                targets.append(item)
        if len(targets) >= 140:
            break

    write_line(fp, "parsed_text_symbols=%d" % len(ordered_text))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_symbol_windows=%d" % len(targets))

    if label == "HIServices" and len(targets) == 0:
        issues.append("%s/%s: zero selected symbol windows" % (label, arch))

    for name, addr in targets:
        emit_symbol_window(fp, rows, ordered_text, name, addr)

    if label == "HIServices":
        for name in ["_SetFrontProcess", "_SetFrontProcessWithOptions", "_TransformProcessType", "_GetFrontProcess"]:
            if name in by_name:
                emit_references(fp, dis_lines, name, by_name[name])


def analyze_binary(fp, label, path, arches, tempdir, issues):
    write_line(fp)
    write_line(fp, "============================================================")
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)

    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        if label == "HIServices":
            issues.append("%s: binary missing" % label)
        return

    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    write_line(fp, out.rstrip())

    for arch in arches:
        analyze_slice(fp, label, path, arch, tempdir, issues)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-setfrontprocess-audit.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])

            write_line(fp, "== Process Manager SetFrontProcess call-path audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product.strip())
            write_line(fp, "build_version=%s" % build.strip())

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            cache_provenance(fp)
            helper_state(fp)

            for label, path, arches in BINARIES:
                analyze_binary(fp, label, path, arches, tempdir, issues)

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
            write_line(fp, "No foreground/activation or registration state was modified by this audit.")
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
