#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-systemservice-transport.txt"
ANALYZER_VERSION = "1"

CARBONCORE = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
SECURITY = "/System/Library/Frameworks/Security.framework/Versions/A/Security"
CORESERVICESD = "/System/Library/CoreServices/coreservicesd"
CORESERVICESD_PLIST = "/System/Library/LaunchDaemons/com.apple.coreservicesd.plist"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

CARBON_TARGET_RE = re.compile(
    r"(scCreateSystemServiceVersion|scCreateSystemService|"
    r"scAddReconnectProc|scRemoveReconnectProc|"
    r"SystemService|ReconnectProc)",
    re.I,
)

SECURITY_TARGET_RE = re.compile(
    r"(SessionGetInfo|SessionCreate|SessionSetDistinguishedUser|"
    r"SecuritySession|AuditSession)",
    re.I,
)

CSTRING_RE = re.compile(
    r"(LaunchApplicationServices|CoreServices\.coreservicesd|coreservicesd|"
    r"SystemService|system service|server port|bootstrap|reconnect|"
    r"SCDontUseServer|SecuritySession|callerSecuritySession)",
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


def emit_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "-- mapped service/session cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "cstring_otool_failed")
        write_line(fp, out.rstrip())
        return 0

    lines = out.splitlines()
    emitted = set()
    count = 0
    for i, line in enumerate(lines):
        if not CSTRING_RE.search(line):
            continue
        count += 1
        lo = max(0, i - 1)
        hi = min(len(lines), i + 2)
        for j in range(lo, hi):
            if j in emitted:
                continue
            emitted.add(j)
            write_line(fp, lines[j])
    write_line(fp, "cstring_match_count=%d" % count)
    return count


def analyze_slice(fp, label, path, arch, target_re, tempdir):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
    ok, out = thin_arch(path, arch, thin)

    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
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

    ordered = parse_symbols(nm_out)
    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return {"arch": arch, "present": True, "targets": [], "cstrings": 0}

    rows = parse_instructions(dis_out)
    selected = [(name, addr) for addr, name in ordered if target_re.search(name)]

    write_line(fp)
    write_line(fp, "-- matching symbols/imports --")
    symbol_count = 0
    helper_re = re.compile(
        r"(bootstrap_|mach_msg|mach_port|CFMachPort|notify_|audit_|SessionGetInfo|"
        r"scCreateSystemServiceVersion|scAddReconnectProc)",
        re.I,
    )
    for line in nm_out.splitlines():
        if target_re.search(line) or helper_re.search(line):
            write_line(fp, line)
            symbol_count += 1
    write_line(fp, "symbol_import_match_count=%d" % symbol_count)
    write_line(fp, "parsed_text_symbols=%d" % len(ordered))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_transport_windows=%d" % len(selected))

    for name, addr in selected:
        emit_window(fp, rows, ordered, name, addr)

    cstrings = emit_cstrings(fp, thin)
    return {
        "arch": arch,
        "present": True,
        "targets": [name for name, addr in selected],
        "cstrings": cstrings,
    }


def analyze_binary(fp, label, path, arches, target_re, tempdir):
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
        results.append(analyze_slice(fp, label, path, arch, target_re, tempdir))
    return results


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
        except IOError as exc:
            data = ""
            write_line(fp, "cache_map_read_error=%s" % exc)
        for path in [CARBONCORE, SECURITY]:
            write_line(fp)
            write_line(fp, "cache_map_path=%s" % path)
            write_line(fp, "cache_map_contains=%s" %
                       ("YES" if path in data else "NO"))
    else:
        write_line(fp, "rosetta_cache_map=MISSING")


def service_state(fp):
    write_line(fp)
    write_line(fp, "== CoreServices service state ==")

    rc, out = run(["/bin/launchctl", "list"])
    write_line(fp, "-- matching launchd jobs --")
    if rc == 0:
        hits = [line for line in out.splitlines()
                if re.search(r"(coreservicesd|pbs)", line, re.I)]
        for line in hits:
            write_line(fp, line)
        if not hits:
            write_line(fp, "(none)")
    else:
        write_line(fp, "launchctl_list_failed")
        write_line(fp, out.rstrip())

    if os.path.isfile(CORESERVICESD):
        write_line(fp, "coreservicesd_sha256=%s" % sha256(CORESERVICESD))
        rc, out = run(["/usr/bin/lipo", "-info", CORESERVICESD])
        write_line(fp, out.rstrip())
    else:
        write_line(fp, "coreservicesd=MISSING")

    if os.path.isfile(CORESERVICESD_PLIST):
        write_line(fp, "coreservicesd_plist_sha256=%s" % sha256(CORESERVICESD_PLIST))
        rc, out = run([
            "/usr/bin/plutil", "-convert", "xml1", "-o", "-", CORESERVICESD_PLIST
        ])
        if rc == 0:
            for line in out.splitlines()[:180]:
                if ("MachServices" in line or
                        "CoreServices.coreservicesd" in line or
                        "Label" in line or
                        "ProgramArguments" in line or
                        "coreservicesd" in line):
                    write_line(fp, line)
        else:
            write_line(fp, "plutil_read_failed")
            write_line(fp, out.rstrip())
    else:
        write_line(fp, "coreservicesd_plist=MISSING")


def has_target(results, arch, fragment):
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
    tempdir = tempfile.mkdtemp(prefix="pm-systemservice-transport.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            write_line(fp, "== Process Manager system-service transport audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            cache_provenance(fp)
            service_state(fp)

            carbon = analyze_binary(
                fp, "CarbonCore", CARBONCORE,
                ["i386", "x86_64", "ppc7400"], CARBON_TARGET_RE, tempdir)
            security = analyze_binary(
                fp, "Security", SECURITY,
                ["i386", "x86_64", "ppc7400"], SECURITY_TARGET_RE, tempdir)

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
                if not has_target(carbon, required_arch,
                                  "scCreateSystemServiceVersion"):
                    issues.append("%s CarbonCore scCreateSystemServiceVersion missing" %
                                  required_arch)
                if not has_target(carbon, required_arch, "scAddReconnectProc"):
                    issues.append("%s CarbonCore scAddReconnectProc missing" %
                                  required_arch)
                if not has_target(security, required_arch, "SessionGetInfo"):
                    issues.append("%s Security SessionGetInfo missing" %
                                  required_arch)

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
            write_line(fp, "No Mach service lookup was performed by custom code.")
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
