#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-process-dispatch.txt"
ANALYZER_VERSION = "1"

LAUNCHSERVICES = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
CORESERVICESD = "/System/Library/CoreServices/coreservicesd"
CORESERVICESD_PLIST = "/System/Library/LaunchDaemons/com.apple.coreservicesd.plist"

TARGET_RE = re.compile(
    r"(SetupCoreApplicationServicesCommunicationPort|"
    r"getProcessDispatchTable|getProcessesServerPort|"
    r"GetOurLSSessionID|InitializeProcessesServices|"
    r"InitializeProcessSharedMemory)",
    re.I,
)

CSTRING_RE = re.compile(
    r"(LaunchApplicationServices|_LSDoInitializeProcessesServices|"
    r"initialize process services|unsupported version|"
    r"Unable to lookup coreservices session port|"
    r"ERROR from coreservicesd|SCDontUseServer|"
    r"GetOurLSSessionIDInit|SessionGetInfo|coreservicesd)",
    re.I,
)


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def write_line(fp, text=""):
    fp.write(text)
    fp.write("\n")


def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]


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
    all_lines = []
    by_name = {}
    for line in text.splitlines():
        all_lines.append(line)
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None or "(__TEXT,__text)" not in line:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        by_name[name] = addr
    ordered.sort()
    return ordered, by_name, all_lines


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


def next_symbol_address(ordered, start):
    for addr, name in ordered:
        if addr > start:
            return addr
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


def emit_window(fp, rows, ordered, name, start, max_bytes=0x7000):
    write_line(fp)
    write_line(fp, "-- symbol window: %s --" % name)
    write_line(fp, "symbol_address=0x%x" % start)
    end = start + max_bytes
    nxt = next_symbol_address(ordered, start)
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


def emit_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "-- mapped process-dispatch cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "cstring_otool_failed")
        write_line(fp, out.rstrip())
        return 0

    lines = out.splitlines()
    emitted = set()
    match_count = 0
    for i, line in enumerate(lines):
        if not CSTRING_RE.search(line):
            continue
        match_count += 1
        lo = max(0, i - 1)
        hi = min(len(lines), i + 2)
        for j in range(lo, hi):
            if j in emitted:
                continue
            emitted.add(j)
            write_line(fp, lines[j])
    write_line(fp, "cstring_match_count=%d" % match_count)
    return match_count


def analyze_launchservices_slice(fp, arch, tempdir):
    thin = os.path.join(tempdir, "LaunchServices.%s" % arch)
    ok, out = thin_arch(LAUNCHSERVICES, arch, thin)

    write_line(fp)
    write_line(fp, "== LaunchServices slice: %s ==" % arch)
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        write_line(fp, out.rstrip())
        return {"arch": arch, "present": False, "targets": [], "cstrings": 0}

    write_line(fp, "slice_sha256=%s" % sha256(thin))
    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "nm_failed")
        write_line(fp, nm_out.rstrip())
        return {"arch": arch, "present": True, "targets": [], "cstrings": 0}

    ordered, by_name, nm_lines = parse_symbols(nm_out)
    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return {"arch": arch, "present": True, "targets": [], "cstrings": 0}

    rows = parse_instructions(dis_out)
    selected = []
    for addr, name in ordered:
        if TARGET_RE.search(name):
            selected.append((name, addr))

    write_line(fp)
    write_line(fp, "-- matching process-dispatch symbols/imports --")
    symbol_match_count = 0
    for line in nm_lines:
        if TARGET_RE.search(line) or re.search(
            r"(scCreateSystemServiceVersion|CFMachPortCreateWithPort|"
            r"SessionGetInfo|scAddReconnectProc)",
            line,
            re.I,
        ):
            write_line(fp, line)
            symbol_match_count += 1
    write_line(fp, "symbol_import_match_count=%d" % symbol_match_count)

    write_line(fp, "parsed_text_symbols=%d" % len(ordered))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_dispatch_windows=%d" % len(selected))
    for name, addr in selected:
        emit_window(fp, rows, ordered, name, addr)

    cstrings = emit_cstrings(fp, thin)
    return {
        "arch": arch,
        "present": True,
        "targets": [name for name, addr in selected],
        "cstrings": cstrings,
    }


def active_state(fp):
    write_line(fp)
    write_line(fp, "== Active CoreServices service state ==")

    rc, out = run(["/bin/ps", "ax", "-o", "pid=,ppid=,command="])
    write_line(fp, "-- matching processes --")
    if rc == 0:
        hits = [line for line in out.splitlines()
                if re.search(r"(coreservicesd|WindowServer|loginwindow)", line, re.I)]
        for line in hits:
            write_line(fp, line)
        if not hits:
            write_line(fp, "(none)")
    else:
        write_line(fp, "ps_failed")
        write_line(fp, out.rstrip())

    rc, out = run(["/bin/launchctl", "list"])
    write_line(fp, "-- matching launchd jobs --")
    if rc == 0:
        hits = [line for line in out.splitlines()
                if re.search(r"(coreservicesd|pbs|WindowServer)", line, re.I)]
        for line in hits:
            write_line(fp, line)
        if not hits:
            write_line(fp, "(none)")
    else:
        write_line(fp, "launchctl_list_failed")
        write_line(fp, out.rstrip())

    write_line(fp)
    write_line(fp, "== coreservicesd executable ==")
    if os.path.isfile(CORESERVICESD):
        write_line(fp, "path=%s" % CORESERVICESD)
        write_line(fp, "sha256=%s" % sha256(CORESERVICESD))
        rc, out = run(["/usr/bin/file", CORESERVICESD])
        write_line(fp, out.rstrip())
        rc, out = run(["/usr/bin/lipo", "-info", CORESERVICESD])
        write_line(fp, out.rstrip())
        rc, out = run(["/usr/bin/otool", "-L", CORESERVICESD])
        write_line(fp, "-- dependencies --")
        write_line(fp, out.rstrip())
    else:
        write_line(fp, "state=MISSING")

    write_line(fp)
    write_line(fp, "== coreservicesd launchd metadata ==")
    if os.path.isfile(CORESERVICESD_PLIST):
        write_line(fp, "path=%s" % CORESERVICESD_PLIST)
        write_line(fp, "sha256=%s" % sha256(CORESERVICESD_PLIST))
        rc, out = run([
            "/usr/bin/plutil", "-convert", "xml1", "-o", "-", CORESERVICESD_PLIST
        ])
        if rc == 0:
            for line in out.splitlines()[:220]:
                write_line(fp, line)
        else:
            write_line(fp, "plutil_read_failed")
            write_line(fp, out.rstrip())
    else:
        write_line(fp, "state=MISSING")


def has_name(results, arch, fragment):
    frag = fragment.lower()
    for result in results:
        if result["arch"] != arch:
            continue
        for name in result["targets"]:
            if frag in name.lower():
                return True
    return False


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-process-dispatch.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            write_line(fp, "== Process Manager / LaunchServices process-dispatch audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            active_state(fp)

            write_line(fp)
            write_line(fp, "============================================================")
            write_line(fp, "== LaunchServices ==")
            write_line(fp, "path=%s" % LAUNCHSERVICES)
            if not os.path.isfile(LAUNCHSERVICES):
                issues.append("LaunchServices binary missing")
                results = []
            else:
                write_line(fp, "sha256=%s" % sha256(LAUNCHSERVICES))
                rc, out = run(["/usr/bin/file", LAUNCHSERVICES])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", LAUNCHSERVICES])
                write_line(fp, out.rstrip())
                results = []
                for arch in ["i386", "x86_64", "ppc7400"]:
                    results.append(analyze_launchservices_slice(fp, arch, tempdir))

            required_fragments = [
                "SetupCoreApplicationServicesCommunicationPort",
                "getProcessDispatchTable",
                "getProcessesServerPort",
                "GetOurLSSessionIDInit",
                "LSNullInitializeProcessesServices",
                "LSServerWrapperInitializeProcessesServices",
                "LSDaemonModeInitializeProcessesServices",
            ]

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if product.startswith("10.6"):
                required_arch = "ppc7400"
            elif product.startswith("10.7"):
                required_arch = "i386"
            else:
                required_arch = None
                issues.append("unsupported OS baseline: %s" % product)

            if required_arch is not None:
                for fragment in required_fragments:
                    if not has_name(results, required_arch, fragment):
                        issues.append("%s LaunchServices target missing: %s" %
                                      (required_arch, fragment))
                have_cstrings = False
                for result in results:
                    if result["arch"] == required_arch and result["cstrings"] > 0:
                        have_cstrings = True
                if not have_cstrings:
                    issues.append("%s process-dispatch cstring mapping missing" %
                                  required_arch)

            if not os.path.isfile(CORESERVICESD):
                issues.append("coreservicesd executable missing")
            if not os.path.isfile(CORESERVICESD_PLIST):
                issues.append("coreservicesd launchd plist missing")

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No environment variable was changed by this audit.")
            write_line(fp, "No process or service was signaled, suspended, restarted, or modified.")
            write_line(fp, "No LaunchServices database or system file was modified.")
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
