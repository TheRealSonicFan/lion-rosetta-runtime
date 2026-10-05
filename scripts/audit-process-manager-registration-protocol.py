#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-launchservices-registration-protocol.txt"
ANALYZER_VERSION = "1"

HISERVICES = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
LAUNCHSERVICES = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
CORESERVICESD = "/System/Library/CoreServices/coreservicesd"

HISERVICES_TARGETS = [
    "__RegisterApplication",
    "_GetCurrentProcess",
    "_GetProcessPID",
    "_GetProcessForPID",
]

LAUNCHSERVICES_TARGETS = [
    "__LSApplicationCheckIn",
    "__LSDoRegisterApplication",
    "__Z22LSReCheckInApplicationv",
    "__ZL45SetupCoreApplicationServicesCommunicationPortv",
    "__Z23getProcessDispatchTablev",
    "_getProcessesServerPort",
    "__ZL21GetOurLSSessionIDInitv",
    "__Z17GetOurLSSessionIDv",
    "__LSGetCurrentApplicationASN",
    "__LSCopyCurrentApplicationASN",
    "__XRegisterApplication",
    "__LSServerRegisterApplication",
]

CSTRING_RE = re.compile(
    r"(LSDoNotAbortIfNoASN|LSDONOTABORTIFNOASN|"
    r"GET ASN FROM CORESERVICES|get application ASN|"
    r"REGISTER PROCESS WITH CPS|coreservicesd|"
    r"_LSDoInitializeProcessesServices|unsupported version|"
    r"Unable to lookup coreservices session port|"
    r"GetOurLSSessionIDInit)",
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
    by_name = {}
    for line in text.splitlines():
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


def emit_window(fp, rows, ordered, name, start, max_bytes=0x5000):
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


def emit_cstring_matches(fp, thin):
    write_line(fp)
    write_line(fp, "-- mapped registration/ASN cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "cstring_otool_failed")
        write_line(fp, out.rstrip())
        return 0

    lines = out.splitlines()
    indexes = []
    for i, line in enumerate(lines):
        if CSTRING_RE.search(line):
            indexes.append(i)

    emitted = set()
    count = 0
    for i in indexes:
        lo = max(0, i - 1)
        hi = min(len(lines), i + 2)
        for j in range(lo, hi):
            if j in emitted:
                continue
            emitted.add(j)
            write_line(fp, lines[j])
        count += 1
    write_line(fp, "cstring_match_count=%d" % count)
    return count


def analyze_slice(fp, label, path, arch, targets, tempdir):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
    ok, out = thin_arch(path, arch, thin)

    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        write_line(fp, out.rstrip())
        return {"arch": arch, "present": False, "targets": [], "cstring_matches": 0}

    write_line(fp, "slice_sha256=%s" % sha256(thin))
    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "nm_failed")
        write_line(fp, nm_out.rstrip())
        return {"arch": arch, "present": True, "targets": [], "cstring_matches": 0}

    ordered, by_name = parse_symbols(nm_out)
    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return {"arch": arch, "present": True, "targets": [], "cstring_matches": 0}

    rows = parse_instructions(dis_out)
    selected = []
    for name in targets:
        if name in by_name:
            selected.append((name, by_name[name]))

    # Include spelling variants/private symbols matching key concepts.
    extra_re = re.compile(
        r"(ApplicationCheckIn|DoRegisterApplication|ReCheckInApplication|"
        r"SetupCoreApplicationServicesCommunicationPort|getProcessDispatchTable|"
        r"getProcessesServerPort|GetOurLSSessionID|GetCurrentApplicationASN|"
        r"XRegisterApplication|LSServerRegisterApplication)",
        re.I,
    )
    for addr, name in ordered:
        if extra_re.search(name) and (name, addr) not in selected:
            selected.append((name, addr))

    write_line(fp, "parsed_text_symbols=%d" % len(ordered))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_protocol_windows=%d" % len(selected))
    for name, addr in selected:
        emit_window(fp, rows, ordered, name, addr)

    cstring_matches = emit_cstring_matches(fp, thin)
    return {
        "arch": arch,
        "present": True,
        "targets": [name for name, addr in selected],
        "cstring_matches": cstring_matches,
    }


def analyze_binary(fp, label, path, arches, targets, tempdir):
    write_line(fp)
    write_line(fp, "============================================================")
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        return []

    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    write_line(fp, out.rstrip())

    results = []
    for arch in arches:
        results.append(analyze_slice(fp, label, path, arch, targets, tempdir))
    return results


def active_service_state(fp):
    write_line(fp)
    write_line(fp, "== Active CoreServices process state ==")

    rc, out = run(["/bin/ps", "ax", "-o", "pid=,ppid=,command="])
    if rc == 0:
        hits = [line for line in out.splitlines()
                if re.search(r"(coreservicesd|WindowServer|loginwindow)", line, re.I)]
        write_line(fp, "-- matching processes --")
        for line in hits:
            write_line(fp, line)
        if not hits:
            write_line(fp, "(none)")
    else:
        write_line(fp, "ps_process_list_failed")
        write_line(fp, out.rstrip())

    rc, out = run(["/bin/ps", "-axo", "pid=,arch=,command="])
    write_line(fp, "-- process architecture attempt --")
    if rc == 0:
        hits = [line for line in out.splitlines()
                if re.search(r"(coreservicesd|WindowServer)", line, re.I)]
        for line in hits:
            write_line(fp, line)
        if not hits:
            write_line(fp, "(no matching rows)")
    else:
        write_line(fp, "ps_arch_column_unavailable")
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

    daemon_dir = "/System/Library/LaunchDaemons"
    write_line(fp, "-- coreservices-related LaunchDaemon plists --")
    if os.path.isdir(daemon_dir):
        names = [name for name in os.listdir(daemon_dir)
                 if "coreservices" in name.lower()]
        for name in sorted(names):
            path = os.path.join(daemon_dir, name)
            write_line(fp, "plist=%s" % path)
            rc, pout = run(["/usr/bin/plutil", "-convert", "xml1", "-o", "-", path])
            if rc == 0:
                for line in pout.splitlines()[:160]:
                    write_line(fp, line)
            else:
                write_line(fp, "plutil_read_failed")
                write_line(fp, pout.rstrip())
        if not names:
            write_line(fp, "(none)")
    else:
        write_line(fp, "LaunchDaemons directory missing")


def has_target(results, wanted, arch=None):
    for result in results:
        if arch is not None and result["arch"] != arch:
            continue
        if wanted in result["targets"]:
            return True
    return False


def any_cstrings(results, arch=None):
    for result in results:
        if arch is not None and result["arch"] != arch:
            continue
        if result["cstring_matches"] > 0:
            return True
    return False


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-ls-registration-protocol.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            write_line(fp, "== Process Manager / LaunchServices registration protocol audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            active_service_state(fp)

            hi = analyze_binary(
                fp, "HIServices", HISERVICES,
                ["i386", "ppc7400"], HISERVICES_TARGETS, tempdir)
            ls = analyze_binary(
                fp, "LaunchServices", LAUNCHSERVICES,
                ["i386", "x86_64", "ppc7400"], LAUNCHSERVICES_TARGETS, tempdir)

            write_line(fp)
            write_line(fp, "== Audit validation ==")

            if product.startswith("10.6"):
                if not has_target(hi, "__RegisterApplication", "ppc7400"):
                    issues.append("Snow Leopard PPC HIServices __RegisterApplication missing")
                for target in [
                    "__LSDoRegisterApplication",
                    "__Z23getProcessDispatchTablev",
                    "_getProcessesServerPort",
                    "__XRegisterApplication",
                    "__LSServerRegisterApplication",
                ]:
                    if not has_target(ls, target, "ppc7400"):
                        issues.append("Snow Leopard PPC LaunchServices target missing: %s" % target)
                if not any_cstrings(hi, "ppc7400"):
                    issues.append("Snow Leopard PPC HIServices cstring mapping missing")
            elif product.startswith("10.7"):
                if not has_target(hi, "__RegisterApplication", "i386"):
                    issues.append("Lion i386 HIServices __RegisterApplication missing")
                for target in [
                    "__LSDoRegisterApplication",
                    "__Z23getProcessDispatchTablev",
                    "_getProcessesServerPort",
                    "__XRegisterApplication",
                    "__LSServerRegisterApplication",
                ]:
                    if not has_target(ls, target, "x86_64"):
                        issues.append("Lion x86_64 LaunchServices target missing: %s" % target)
                if not any_cstrings(hi, "i386"):
                    issues.append("Lion i386 HIServices cstring mapping missing")
            else:
                issues.append("unsupported OS baseline: %s" % product)

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
            write_line(fp, "No service was restarted by this audit.")
            write_line(fp, "No registration database or system file was modified by this audit.")
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
