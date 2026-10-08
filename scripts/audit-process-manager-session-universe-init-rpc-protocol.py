#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-session-universe-init-rpc-protocol.txt"
ANALYZER_VERSION = "1"

CARBONCORE = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

TARGET_NAMES = [
    "__SCSessionUniverseByUIDAcquireAndLock",
    "__scclient_SCSessionUniverseInitConnection_rpc",
    "__XSCSessionUniverseInitConnection_rpc",
    "__scserver_SCSessionUniverseInitConnection_rpc",
    "__scclient_SCSessionUniverseMapSharedSegment_rpc",
    "__XSCSessionUniverseMapSharedSegment_rpc",
    "__scserver_SCSessionUniverseMapSharedSegment_rpc",
    "__scclient_SCSessionUniverseDisconnect_rpc",
    "__XSCSessionUniverseDisconnect_rpc",
    "__scserver_SCSessionUniverseDisconnect_rpc",
    "_SCGetSessionLocalUniverseInfo",
    "__SCConstructMappedUniverse",
    "_scGetServerCheckinPort",
    "__Z15scHandleMessageP17mach_msg_header_tPFiS0_S0_EPmPh",
]

TARGET_RE = re.compile(
    r"(SCSessionUniverseByUIDAcquireAndLock|"
    r"SCSessionUniverseInitConnection_rpc|"
    r"SCSessionUniverseMapSharedSegment_rpc|"
    r"SCSessionUniverseDisconnect_rpc|"
    r"SCGetSessionLocalUniverseInfo|"
    r"SCConstructMappedUniverse|"
    r"scGetServerCheckinPort|"
    r"scHandleMessage)",
    re.I,
)

HELPER_RE = re.compile(
    r"(mach_msg|mig_|NDR|bootstrap_|"
    r"SCSessionUniverse|SCClientSession|SCServerSession|"
    r"getpid|getuid|geteuid|audit_|"
    r"pthread_mutex|CFMachPort)",
    re.I,
)

CSTRING_RE = re.compile(
    r"(SCSessionUniverseInitConnection_rpc|"
    r"SCSessionUniverseMapSharedSegment_rpc|"
    r"SCSessionUniverseDisconnect_rpc|"
    r"MIG|mach|universe|session|"
    r"failed|error|coreservicesd)",
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
    lines = []
    for line in text.splitlines():
        lines.append(line)
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None or "(__TEXT,__text)" not in line:
            continue
        ordered.append((addr, parts[-1]))
    ordered.sort()
    return ordered, lines


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
    write_line(fp, "-- mapped RPC/session cstrings --")
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


def analyze_slice(fp, arch, tempdir):
    thin = os.path.join(tempdir, "CarbonCore.%s" % arch)
    ok, out = thin_arch(CARBONCORE, arch, thin)

    write_line(fp)
    write_line(fp, "== CarbonCore slice: %s ==" % arch)
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        write_line(fp, out.rstrip())
        return {"arch": arch, "present": False, "analyzed": False,
                "targets": [], "cstrings": 0}

    write_line(fp, "slice_sha256=%s" % sha256(thin))
    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "nm_failed")
        write_line(fp, nm_out.rstrip())
        return {"arch": arch, "present": True, "analyzed": False,
                "targets": [], "cstrings": 0}

    ordered, nm_lines = parse_symbols(nm_out)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return {"arch": arch, "present": True, "analyzed": False,
                "targets": [], "cstrings": 0}

    rows = parse_instructions(dis_out)
    selected = [(name, addr) for addr, name in ordered if TARGET_RE.search(name)]

    write_line(fp)
    write_line(fp, "-- matching RPC/session symbols and imports --")
    match_count = 0
    for line in nm_lines:
        if TARGET_RE.search(line) or HELPER_RE.search(line):
            write_line(fp, line)
            match_count += 1
    write_line(fp, "symbol_import_match_count=%d" % match_count)
    write_line(fp, "parsed_text_symbols=%d" % len(ordered))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_rpc_windows=%d" % len(selected))

    for name, addr in selected:
        emit_window(fp, rows, ordered, name, addr)

    cstrings = emit_cstrings(fp, thin)
    return {
        "arch": arch,
        "present": True,
        "analyzed": True,
        "targets": [name for name, addr in selected],
        "cstrings": cstrings,
    }


def cache_provenance(fp):
    write_line(fp)
    write_line(fp, "== Rosetta cache provenance ==")
    for path, label in [(ROSETTA_CACHE, "rosetta_cache"),
                        (ROSETTA_MAP, "rosetta_cache_map")]:
        if os.path.isfile(path):
            write_line(fp, "%s_sha256=%s" % (label, sha256(path)))
        else:
            write_line(fp, "%s=MISSING" % label)
    if os.path.isfile(ROSETTA_MAP):
        rc, out = run(["/usr/bin/grep", "-F", CARBONCORE, ROSETTA_MAP])
        write_line(fp, "cache_map_contains_CarbonCore=%s" %
                   ("YES" if rc == 0 else "NO"))


def has_target(result, fragment):
    frag = fragment.lower()
    for name in result["targets"]:
        if frag in name.lower():
            return True
    return False


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-session-universe-rpc.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            write_line(fp, "== Process Manager SCSessionUniverse InitConnection RPC protocol audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== Prior dynamic/static evidence to correlate ==")
            write_line(fp, "lion_fault=SIGBUS_at_0x0000003c")
            write_line(fp, "lion_ppc_register_r10=0xd0feffff")
            write_line(fp, "lion_ppc_register_r10_byteswapped=0xfffffed0")
            write_line(fp, "lion_ppc_register_r10_signed=-304")
            write_line(fp, "mig_bad_arguments=-304")
            write_line(fp, "snow_ppc_call_shape=port,pid,uid,arch_or_layout,out")
            write_line(fp, "snow_i386_call_shape=port,pid,uid,2,out")
            write_line(fp, "snow_x86_64_call_shape=port,pid,uid,3,out")
            write_line(fp, "lion_i386_call_shape=port,uid,2,out")
            write_line(fp, "lion_x86_64_call_shape=port,uid,3,out")
            write_line(fp, "call_shape_lines_are_prior_binary_observations_not_protocol_assumptions")

            results = []
            if not os.path.isfile(CARBONCORE):
                issues.append("CarbonCore binary missing")
            else:
                write_line(fp)
                write_line(fp, "============================================================")
                write_line(fp, "== CarbonCore ==")
                write_line(fp, "path=%s" % CARBONCORE)
                write_line(fp, "sha256=%s" % sha256(CARBONCORE))
                rc, out = run(["/usr/bin/file", CARBONCORE])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", CARBONCORE])
                write_line(fp, out.rstrip())
                for arch in ["ppc7400", "i386", "x86_64"]:
                    results.append(analyze_slice(fp, arch, tempdir))

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if product.startswith("10.6"):
                required_arch = "ppc7400"
            elif product.startswith("10.7"):
                required_arch = "i386"
            else:
                required_arch = None
                issues.append("unsupported OS baseline: %s" % product)

            required_result = None
            if required_arch is not None:
                for result in results:
                    if result["arch"] == required_arch:
                        required_result = result
                        break
                if required_result is None or not required_result["present"]:
                    issues.append("%s CarbonCore slice missing" % required_arch)
                elif not required_result["analyzed"]:
                    issues.append("%s CarbonCore slice could not be analyzed" % required_arch)
                else:
                    for fragment in [
                        "SCSessionUniverseByUIDAcquireAndLock",
                        "scclient_SCSessionUniverseInitConnection_rpc",
                        "XSCSessionUniverseInitConnection_rpc",
                        "scserver_SCSessionUniverseInitConnection_rpc",
                    ]:
                        if not has_target(required_result, fragment):
                            issues.append("%s target missing: %s" %
                                          (required_arch, fragment))
                    if required_result["cstrings"] == 0:
                        issues.append("%s RPC/session cstring mapping missing" %
                                      required_arch)

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No CarbonCore private API was called by custom code.")
            write_line(fp, "No bootstrap lookup or Mach/MIG request was sent by custom code.")
            write_line(fp, "No environment variable was changed.")
            write_line(fp, "No process or service was signaled, restarted, or modified.")
            write_line(fp, "No system file was modified.")
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
