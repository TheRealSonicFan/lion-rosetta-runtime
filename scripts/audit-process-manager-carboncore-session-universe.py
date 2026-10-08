#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-carboncore-session-universe.txt"
ANALYZER_VERSION = "1"

CARBONCORE = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
CORESERVICESD = "/System/Library/CoreServices/coreservicesd"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

TARGET_RE = re.compile(
    r"(SCSessionUniverseByUIDAcquireAndLock|"
    r"FSNodeStorageGetAndLockCurrentUniverse|"
    r"FileIDTreeGetVRefNumForDevice|"
    r"FSMount|"
    r"PathGetObjectInfo|"
    r"FSPathMakeRefInternal|"
    r"GetBugsForOurBundleIDFromCoreservicesd|"
    r"CSCheckFix)",
    re.I,
)

HELPER_RE = re.compile(
    r"(SCSession|SCClientSession|SCServerSession|"
    r"Universe|mach_msg|mig_|bootstrap_|"
    r"SessionGetInfo|getuid|geteuid|getpid|"
    r"pthread_mutex|CFMachPort|scclient_|"
    r"CoreServices\.coreservicesd)",
    re.I,
)

CSTRING_RE = re.compile(
    r"(MUTX|Session|Universe|UID|"
    r"Bugs|Fix|resource fork|"
    r"coreservicesd|FileIDTree|FSMount|"
    r"lock|mutex|Mach|MIG)",
    re.I,
)

INTERESTING_RE = re.compile(
    r"(4d55|5458|MUTX|"
    r"0x2c|0x34|0x3c|"
    r"fffffed0|d0feffff)",
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


def emit_window(fp, rows, ordered, name, start, max_bytes=0x5000):
    write_line(fp)
    write_line(fp, "-- symbol window: %s --" % name)
    write_line(fp, "symbol_address=0x%x" % start)
    end = start + max_bytes
    nxt = next_symbol_address(ordered, start)
    if nxt is not None:
        end = min(end, nxt)
    count = 0
    interesting = 0
    for addr, line in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        write_line(fp, line)
        count += 1
        if INTERESTING_RE.search(line):
            interesting += 1
    write_line(fp, "instruction_lines=%d" % count)
    write_line(fp, "interesting_instruction_lines=%d" % interesting)


def emit_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "-- mapped session/universe cstrings --")
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


def analyze_slice(fp, label, path, arch, tempdir):
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

    ordered, nm_lines = parse_symbols(nm_out)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return {"arch": arch, "present": True, "targets": [], "cstrings": 0}

    rows = parse_instructions(dis_out)
    selected = [(name, addr) for addr, name in ordered if TARGET_RE.search(name)]

    write_line(fp)
    write_line(fp, "-- matching target/helper symbols and imports --")
    matches = 0
    for line in nm_lines:
        if TARGET_RE.search(line) or HELPER_RE.search(line):
            write_line(fp, line)
            matches += 1
    write_line(fp, "symbol_import_match_count=%d" % matches)
    write_line(fp, "parsed_text_symbols=%d" % len(ordered))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))
    write_line(fp, "selected_target_windows=%d" % len(selected))

    for name, addr in selected:
        emit_window(fp, rows, ordered, name, addr)

    cstrings = emit_cstrings(fp, thin)
    return {
        "arch": arch,
        "present": True,
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
        for needle in [CARBONCORE]:
            rc, out = run(["/usr/bin/grep", "-F", needle, ROSETTA_MAP])
            write_line(fp, "cache_map_contains_%s=%s" %
                       ("CarbonCore", "YES" if rc == 0 else "NO"))


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
    tempdir = tempfile.mkdtemp(prefix="pm-carboncore-session-universe.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            write_line(fp, "== Process Manager CarbonCore session-universe audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== Observed Lion postmortem constants ==")
            write_line(fp, "fault_address=0x0000003c")
            write_line(fp, "ppc_r3_at_fault=0x0000003c")
            write_line(fp, "ppc_r9_at_fault=0x4d555458")
            write_line(fp, "ppc_r10_at_fault=0xd0feffff")
            write_line(fp, "ppc_r10_byteswapped=0xfffffed0")
            write_line(fp, "ppc_r10_byteswapped_signed=-304")
            write_line(fp, "note=-304 is MIG_BAD_ARGUMENTS; register liveness/causality is not assumed by this audit")

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
                    results.append(analyze_slice(fp, "CarbonCore", CARBONCORE,
                                                 arch, tempdir))

            write_line(fp)
            write_line(fp, "== coreservicesd symbol/import inventory ==")
            if os.path.isfile(CORESERVICESD):
                write_line(fp, "path=%s" % CORESERVICESD)
                write_line(fp, "sha256=%s" % sha256(CORESERVICESD))
                rc, out = run(["/usr/bin/file", CORESERVICESD])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", CORESERVICESD])
                write_line(fp, out.rstrip())
                rc, nm_out = run(["/usr/bin/nm", "-nm", CORESERVICESD])
                if rc == 0:
                    count = 0
                    for line in nm_out.splitlines():
                        if TARGET_RE.search(line) or HELPER_RE.search(line):
                            write_line(fp, line)
                            count += 1
                    write_line(fp, "coreservicesd_symbol_import_match_count=%d" % count)
                else:
                    write_line(fp, "coreservicesd_nm_failed")
                    write_line(fp, nm_out.rstrip())
            else:
                write_line(fp, "state=MISSING")

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
                for fragment in [
                    "SCSessionUniverseByUIDAcquireAndLock",
                    "FSNodeStorageGetAndLockCurrentUniverse",
                    "GetBugsForOurBundleIDFromCoreservicesd",
                    "CSCheckFix",
                ]:
                    if not has_target(results, required_arch, fragment):
                        issues.append("%s CarbonCore target missing: %s" %
                                      (required_arch, fragment))

            if not os.path.isfile(CORESERVICESD):
                issues.append("coreservicesd executable missing")

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No CarbonCore/CoreServices API was called by custom code.")
            write_line(fp, "No bootstrap or Mach RPC was sent by custom code.")
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
