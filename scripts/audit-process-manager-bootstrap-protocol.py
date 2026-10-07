#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-bootstrap-protocol.txt"
ANALYZER_VERSION = "1"

LIBLAUNCH_CANDIDATES = [
    "/usr/lib/system/liblaunch.dylib",
    "/usr/lib/libSystem.B.dylib",
]
LAUNCHD = "/sbin/launchd"
HEADER_CANDIDATES = [
    "/usr/include/servers/bootstrap.h",
    "/usr/include/servers/bootstrap_priv.h",
    "/usr/include/mach/mig_errors.h",
]

TARGET_RE = re.compile(
    r"(bootstrap_look_up2|bootstrap_look_up3|"
    r"vproc_mig_look_up2|job_mig_look_up2|"
    r"_X.*look_up2|look_up2|bootstrap_init)",
    re.I,
)

IMPORT_RE = re.compile(
    r"(mach_msg|mig_|bootstrap_|vproc_mig_|job_mig_)",
    re.I,
)

HEADER_RE = re.compile(
    r"(bootstrap_look_up2|bootstrap_look_up3|"
    r"MIG_BAD_ARGUMENTS|MIG_TYPE_ERROR|"
    r"BOOTSTRAP_PER_PID_SERVICE|BOOTSTRAP_PRIVILEGED_SERVER)",
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


def emit_window(fp, insns, ordered, name, start, max_bytes=0x2400):
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


def analyze_slice(fp, path, label, arch, tempdir):
    dst = os.path.join(tempdir, "%s.%s" % (label, arch))
    ok, out = thin(path, arch, dst)
    line(fp)
    line(fp, "== %s slice: %s ==" % (label, arch))
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        line(fp, out.rstrip())
        return {"arch": arch, "targets": [], "present": False}

    line(fp, "slice_sha256=%s" % sha256(dst))

    rc, nmout = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        line(fp, "nm_failed")
        line(fp, nmout.rstrip())
        return {"arch": arch, "targets": [], "present": True}

    ordered, raw = parse_symbols(nmout)
    selected = [(name, addr) for addr, name in ordered if TARGET_RE.search(name)]

    line(fp, "-- matching lookup/MIG symbols and imports --")
    count = 0
    for row in raw:
        if TARGET_RE.search(row) or IMPORT_RE.search(row):
            line(fp, row)
            count += 1
    line(fp, "symbol_import_match_count=%d" % count)
    line(fp, "parsed_text_symbols=%d" % len(ordered))
    line(fp, "selected_lookup_windows=%d" % len(selected))

    rc, dis = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        line(fp, "disassembly_failed")
        line(fp, dis.rstrip())
        return {"arch": arch, "targets": [n for n, a in selected], "present": True}

    insns = parse_insns(dis)
    line(fp, "parsed_instruction_lines=%d" % len(insns))
    for name, addr in selected:
        emit_window(fp, insns, ordered, name, addr)

    return {"arch": arch, "targets": [n for n, a in selected], "present": True}


def choose_liblaunch():
    for path in LIBLAUNCH_CANDIDATES:
        if os.path.isfile(path):
            return path
    return None


def emit_file_identity(fp, label, path):
    line(fp)
    line(fp, "== %s ==" % label)
    line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        line(fp, "state=MISSING")
        return
    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    line(fp, out.rstrip())
    if os.path.exists("/usr/bin/lipo"):
        rc, out = run(["/usr/bin/lipo", "-info", path])
        line(fp, out.rstrip())


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
        with open(path, "r") as h:
            rows = h.readlines()
        emitted = 0
        for i, row in enumerate(rows):
            if not HEADER_RE.search(row):
                continue
            lo = max(0, i - 2)
            hi = min(len(rows), i + 3)
            for j in range(lo, hi):
                line(fp, "%5d: %s" % (j + 1, rows[j].rstrip()))
            emitted += 1
        line(fp, "header_match_count=%d" % emitted)
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


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-bootstrap-protocol.")
    issues = []

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            product = product.strip()

            line(fp, "== Process Manager launchd/bootstrap protocol audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build.strip())
            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            line(fp, out.rstrip())

            client = choose_liblaunch()
            if client is None:
                issues.append("no liblaunch/libSystem client binary found")
                line(fp, "bootstrap_client=MISSING")
                client_results = []
            else:
                emit_file_identity(fp, "Bootstrap client binary", client)
                client_results = []
                for arch in ["i386", "x86_64", "ppc7400"]:
                    client_results.append(
                        analyze_slice(fp, client, "bootstrap-client", arch, tempdir)
                    )

            emit_file_identity(fp, "launchd server binary", LAUNCHD)
            server_results = []
            if os.path.isfile(LAUNCHD):
                for arch in ["i386", "x86_64", "ppc7400"]:
                    server_results.append(
                        analyze_slice(fp, LAUNCHD, "launchd", arch, tempdir)
                    )
            else:
                issues.append("launchd binary missing")

            emit_headers(fp)

            line(fp)
            line(fp, "== Audit validation ==")
            if product.startswith("10.6"):
                required_arch = "ppc7400"
                required = ["bootstrap_look_up2", "vproc_mig_look_up2"]
            elif product.startswith("10.7"):
                required_arch = "i386"
                required = ["bootstrap_look_up2", "vproc_mig_look_up2"]
            else:
                required_arch = None
                required = []
                issues.append("unsupported OS baseline: %s" % product)

            if required_arch is not None:
                for fragment in required:
                    if not has_target(client_results, required_arch, fragment):
                        issues.append("%s bootstrap client target missing: %s" %
                                      (required_arch, fragment))

            # launchd is commonly more stripped than liblaunch.  Record any
            # server-side look_up2 windows, but do not make their symbol
            # visibility a PASS requirement.
            visible_server = 0
            for result in server_results:
                for name in result["targets"]:
                    if "look_up2" in name.lower():
                        visible_server += 1
            line(fp, "visible_launchd_look_up2_windows=%d" % visible_server)

            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC application was launched by this audit.")
            line(fp, "No bootstrap or Mach-service lookup was performed by custom code.")
            line(fp, "No Mach message was sent by custom code.")
            line(fp, "No process or service was signaled, suspended, restarted, or modified.")
            line(fp, "No environment variable was changed.")
            line(fp, "No system file was modified.")
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
