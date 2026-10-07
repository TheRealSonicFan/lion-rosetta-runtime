#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-security-session-protocol.txt"
ANALYZER_VERSION = "1"

SECURITY = "/System/Library/Frameworks/Security.framework/Versions/A/Security"
SECURITYD = "/usr/sbin/securityd"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

HEADER_CANDIDATES = [
    "/usr/include/Security/AuthSession.h",
    "/System/Library/Frameworks/Security.framework/Headers/AuthSession.h",
    "/usr/include/Security/cssmerr.h",
    "/System/Library/Frameworks/Security.framework/Headers/cssmerr.h",
    "/usr/include/mach/mig_errors.h",
]

CLIENT_TARGET_RE = re.compile(
    r"(SessionGetInfo|ClientSession.*getSessionInfo|"
    r"ucsp_client_getSessionInfo|CommonCriteria.*AuditInfo|"
    r"ClientSession.*activate|ClientSession.*Global|findSecurityd|"
    r"CssmError.*cssmError)",
    re.I,
)

SERVER_TARGET_RE = re.compile(
    r"(ucsp_server|ucsp.*routine|_X.*getSessionInfo|"
    r"getSessionInfo|setupSession|Session)",
    re.I,
)

IMPORT_RE = re.compile(
    r"(mach_msg|mig_|bootstrap_|audit_|getaudit|setaudit|"
    r"SessionGetInfo|getSessionInfo|SecurityServer|AuditInfo|ucsp_)",
    re.I,
)

CSTRING_RE = re.compile(
    r"(SessionGetInfo|SecurityServer|SECURITYSERVER|"
    r"session server|session setup|contact with|"
    r"Mach %d|non-OSStatus error|"
    r"com\.apple\.SecurityServer)",
    re.I,
)

HEADER_RE = re.compile(
    r"(callerSecuritySession|noSecuritySession|errSessionInvalidId|"
    r"CSSM_ERRCODE_INTERNAL_ERROR|MIG_BAD_ID|MIG_BAD_ARGUMENTS)",
    re.I,
)


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def line(fp, text=""):
    fp.write(text)
    fp.write("\n")


def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]


def parse_hex(token):
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
    raw = []
    for row in text.splitlines():
        raw.append(row)
        parts = row.split()
        if len(parts) < 2:
            continue
        addr = parse_hex(parts[0])
        if addr is None or "(__TEXT,__text)" not in row:
            continue
        ordered.append((addr, parts[-1]))
    ordered.sort()
    return ordered, raw


def parse_insns(text):
    rows = []
    for row in text.splitlines():
        parts = row.split(None, 1)
        if not parts:
            continue
        addr = parse_hex(parts[0])
        if addr is not None:
            rows.append((addr, row))
    return rows


def next_symbol(ordered, start):
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


def thin(path, arch, dst):
    ok, out = verify_arch(path, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", path, "-thin", arch, "-output", dst])
    return rc == 0, out


def emit_window(fp, insns, ordered, name, start, max_bytes=0x3000):
    line(fp)
    line(fp, "-- symbol window: %s --" % name)
    line(fp, "symbol_address=0x%x" % start)
    end = start + max_bytes
    nxt = next_symbol(ordered, start)
    if nxt is not None:
        end = min(end, nxt)
    count = 0
    for addr, row in insns:
        if addr < start:
            continue
        if addr >= end:
            break
        line(fp, row)
        count += 1
    line(fp, "instruction_lines=%d" % count)


def emit_cstrings(fp, thin_path):
    line(fp)
    line(fp, "-- mapped Security/session cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin_path])
    if rc != 0:
        line(fp, "cstring_otool_failed")
        line(fp, out.rstrip())
        return 0

    rows = out.splitlines()
    emitted = set()
    count = 0
    for i, row in enumerate(rows):
        if not CSTRING_RE.search(row):
            continue
        count += 1
        lo = max(0, i - 1)
        hi = min(len(rows), i + 2)
        for j in range(lo, hi):
            if j in emitted:
                continue
            emitted.add(j)
            line(fp, rows[j])
    line(fp, "cstring_match_count=%d" % count)
    return count


def analyze_slice(fp, label, path, arch, target_re, tempdir):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    dst = os.path.join(tempdir, "%s.%s" % (safe, arch))
    ok, out = thin(path, arch, dst)

    line(fp)
    line(fp, "== %s slice: %s ==" % (label, arch))
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        line(fp, out.rstrip())
        return {"arch": arch, "present": False, "targets": [], "imports": []}

    line(fp, "slice_sha256=%s" % sha256(dst))

    rc, deps = run(["/usr/bin/otool", "-L", dst])
    line(fp, "-- dependencies --")
    line(fp, deps.rstrip())

    rc, nmout = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        line(fp, "nm_failed")
        line(fp, nmout.rstrip())
        return {"arch": arch, "present": True, "targets": [], "imports": []}

    ordered, raw = parse_symbols(nmout)
    selected = [(name, addr) for addr, name in ordered if target_re.search(name)]

    line(fp)
    line(fp, "-- matching Security/session symbols and imports --")
    matches = []
    for row in raw:
        if target_re.search(row) or IMPORT_RE.search(row):
            line(fp, row)
            matches.append(row)
    line(fp, "symbol_import_match_count=%d" % len(matches))
    line(fp, "parsed_text_symbols=%d" % len(ordered))
    line(fp, "selected_session_windows=%d" % len(selected))

    rc, dis = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        line(fp, "disassembly_failed")
        line(fp, dis.rstrip())
        emit_cstrings(fp, dst)
        return {
            "arch": arch,
            "present": True,
            "targets": [name for name, addr in selected],
            "imports": matches,
        }

    insns = parse_insns(dis)
    line(fp, "parsed_instruction_lines=%d" % len(insns))
    for name, addr in selected:
        emit_window(fp, insns, ordered, name, addr)

    emit_cstrings(fp, dst)
    return {
        "arch": arch,
        "present": True,
        "targets": [name for name, addr in selected],
        "imports": matches,
    }


def analyze_binary(fp, label, path, arches, target_re, tempdir):
    line(fp)
    line(fp, "============================================================")
    line(fp, "== %s ==" % label)
    line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        line(fp, "state=MISSING")
        return []

    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    line(fp, out.rstrip())

    results = []
    for arch in arches:
        results.append(analyze_slice(fp, label, path, arch, target_re, tempdir))
    return results


def cache_provenance(fp):
    line(fp)
    line(fp, "== Rosetta shared-cache provenance ==")
    if os.path.isfile(ROSETTA_CACHE):
        line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
    else:
        line(fp, "rosetta_cache=MISSING")

    if os.path.isfile(ROSETTA_MAP):
        line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
        try:
            data = open(ROSETTA_MAP, "r").read()
        except IOError as exc:
            data = ""
            line(fp, "cache_map_read_error=%s" % exc)
        line(fp, "cache_map_path=%s" % SECURITY)
        line(fp, "cache_map_contains_security=%s" %
             ("YES" if SECURITY in data else "NO"))
    else:
        line(fp, "rosetta_cache_map=MISSING")


def securityd_state(fp):
    line(fp)
    line(fp, "== securityd launchd state ==")
    rc, out = run(["/bin/launchctl", "list"])
    if rc != 0:
        line(fp, "launchctl_list_failed")
        line(fp, out.rstrip())
        return
    hits = [row for row in out.splitlines()
            if re.search(r"(securityd|SecurityServer)", row, re.I)]
    if hits:
        for row in hits:
            line(fp, row)
    else:
        line(fp, "(no matching launchctl rows)")


def emit_headers(fp):
    line(fp)
    line(fp, "== Installed header evidence ==")
    found = 0
    for path in HEADER_CANDIDATES:
        line(fp)
        line(fp, "-- %s --" % path)
        if not os.path.isfile(path):
            line(fp, "MISSING")
            continue
        found += 1
        try:
            rows = open(path, "r").readlines()
        except IOError as exc:
            line(fp, "read_error=%s" % exc)
            continue
        emitted = set()
        count = 0
        for i, row in enumerate(rows):
            if not HEADER_RE.search(row):
                continue
            count += 1
            lo = max(0, i - 2)
            hi = min(len(rows), i + 3)
            for j in range(lo, hi):
                if j in emitted:
                    continue
                emitted.add(j)
                line(fp, "%5d: %s" % (j + 1, rows[j].rstrip()))
        line(fp, "header_match_count=%d" % count)
    line(fp, "installed_header_files_found=%d" % found)


def has_target(results, arch, fragment):
    frag = fragment.lower()
    for result in results:
        if result["arch"] != arch:
            continue
        for name in result["targets"]:
            if frag in name.lower():
                return True
    return False


def count_target(results, arch, fragment):
    frag = fragment.lower()
    count = 0
    for result in results:
        if result["arch"] != arch:
            continue
        for name in result["targets"]:
            if frag in name.lower():
                count += 1
    return count


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-security-session-protocol.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            line(fp, "== Process Manager Security session protocol audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            line(fp, out.rstrip())

            cache_provenance(fp)
            securityd_state(fp)

            client_results = analyze_binary(
                fp, "Security framework", SECURITY,
                ["i386", "x86_64", "ppc7400"], CLIENT_TARGET_RE, tempdir)

            server_results = analyze_binary(
                fp, "securityd server", SECURITYD,
                ["i386", "x86_64", "ppc7400"], SERVER_TARGET_RE, tempdir)

            emit_headers(fp)

            line(fp)
            line(fp, "== Protocol-source correlation to verify against binaries ==")
            line(fp, "legacy_ucsp_subsystem_base=1000")
            line(fp, "legacy_getSessionInfo_ordinal=65")
            line(fp, "legacy_getSessionInfo_request_id=1065")
            line(fp, "legacy_getSessionInfo_request_id_hex=0x00000429")
            line(fp, "lion_source_slot_65=skip")
            line(fp, "status_1_symbolic=CSSM_ERRCODE_INTERNAL_ERROR")
            line(fp, "source_correlation_is_context_not_binary_proof=YES")

            line(fp)
            line(fp, "== Audit validation ==")
            if product.startswith("10.6"):
                required_arch = "ppc7400"
                if not has_target(client_results, required_arch, "SessionGetInfo"):
                    issues.append("%s Security SessionGetInfo missing" % required_arch)
                if not has_target(client_results, required_arch, "ClientSession"):
                    issues.append("%s legacy ClientSession path missing" % required_arch)
                if not os.path.isfile(SECURITYD):
                    issues.append("securityd binary missing")
            elif product.startswith("10.7"):
                required_arch = "i386"
                if not has_target(client_results, required_arch, "SessionGetInfo"):
                    issues.append("%s Security SessionGetInfo missing" % required_arch)
                if not has_target(client_results, required_arch, "AuditInfo"):
                    issues.append("%s native AuditInfo path missing" % required_arch)
                if not os.path.isfile(SECURITYD):
                    issues.append("securityd binary missing")
            else:
                required_arch = None
                issues.append("unsupported OS baseline: %s" % product)

            if required_arch is not None:
                line(fp, "required_arch=%s" % required_arch)
                line(fp, "visible_client_getSessionInfo_windows=%d" %
                     count_target(client_results, required_arch, "getSessionInfo"))
                line(fp, "visible_securityd_getSessionInfo_windows=%d" %
                     count_target(server_results, required_arch, "getSessionInfo"))
                line(fp, "visible_securityd_ucsp_windows=%d" %
                     count_target(server_results, required_arch, "ucsp"))

            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC application was launched by this audit.")
            line(fp, "No SecuritySession API was called by custom code.")
            line(fp, "No bootstrap or Mach-service lookup was performed by custom code.")
            line(fp, "No Mach message was sent by custom code.")
            line(fp, "No environment variable was changed.")
            line(fp, "No process or service was signaled, suspended, restarted, or modified.")
            line(fp, "No system file, Rosetta component, Security framework, or XNU image was modified.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

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
