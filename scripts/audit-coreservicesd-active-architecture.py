#!/usr/bin/python
from __future__ import print_function

import os
import re
import subprocess
import sys

DEFAULT_REPORT = "./process-manager-coreservicesd-architecture.txt"
ANALYZER_VERSION = "1"

P_LP64 = 0x00000004
P_TRANSLATED = 0x00020000
CORESERVICESD = "/System/Library/CoreServices/coreservicesd"


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def write_line(fp, text=""):
    fp.write(text)
    fp.write("\n")


def parse_flags(token):
    token = token.strip()
    if token.lower().startswith("0x"):
        token = token[2:]
    if not token:
        return None
    try:
        return int(token, 16)
    except ValueError:
        return None


def get_process_rows():
    rc, out = run(["/bin/ps", "-axo", "pid=,ppid=,flags=,command="])
    return rc, out


def find_coreservicesd_rows(text):
    rows = []
    for line in text.splitlines():
        if CORESERVICESD not in line:
            continue
        parts = line.strip().split(None, 3)
        if len(parts) < 4:
            continue
        try:
            pid = int(parts[0], 10)
            ppid = int(parts[1], 10)
        except ValueError:
            continue
        flags = parse_flags(parts[2])
        rows.append((pid, ppid, parts[2], flags, parts[3], line))
    return rows


def classify(flags):
    if flags is None:
        return "UNKNOWN"
    if flags & P_TRANSLATED:
        return "PPC_TRANSLATED"
    if flags & P_LP64:
        return "X86_64_LP64"
    return "I386_ILP32"


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []

    with open(report, "w") as fp:
        _, product = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build = run(["/usr/bin/sw_vers", "-buildVersion"])

        write_line(fp, "== Active coreservicesd architecture audit ==")
        write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        write_line(fp, "product_version=%s" % product.strip())
        write_line(fp, "build_version=%s" % build.strip())
        write_line(fp, "P_LP64=0x%08x" % P_LP64)
        write_line(fp, "P_TRANSLATED=0x%08x" % P_TRANSLATED)

        rc, out = run(["/usr/sbin/sysctl", "hw.optional.x86_64"])
        write_line(fp, out.rstrip())

        write_line(fp)
        write_line(fp, "== coreservicesd executable ==")
        if os.path.isfile(CORESERVICESD):
            rc, out = run(["/usr/bin/file", CORESERVICESD])
            write_line(fp, out.rstrip())
            rc, out = run(["/usr/bin/lipo", "-info", CORESERVICESD])
            write_line(fp, out.rstrip())
        else:
            issues.append("coreservicesd executable missing")
            write_line(fp, "state=MISSING")

        write_line(fp)
        write_line(fp, "== process flags ==")
        rc, out = get_process_rows()
        if rc != 0:
            issues.append("ps flags query failed")
            write_line(fp, "ps_flags_query_failed")
            write_line(fp, out.rstrip())
            rows = []
        else:
            rows = find_coreservicesd_rows(out)
            if not rows:
                issues.append("active coreservicesd not found")
                write_line(fp, "active_coreservicesd=NOT_FOUND")
            for pid, ppid, flags_token, flags, command, raw in rows:
                write_line(fp, "raw=%s" % raw.strip())
                write_line(fp, "pid=%d" % pid)
                write_line(fp, "ppid=%d" % ppid)
                write_line(fp, "flags_raw=%s" % flags_token)
                if flags is None:
                    issues.append("unable to parse process flags for pid %d" % pid)
                    write_line(fp, "flags_parse=FAIL")
                    write_line(fp, "active_arch=UNKNOWN")
                else:
                    write_line(fp, "flags_value=0x%08x" % flags)
                    write_line(fp, "p_lp64=%d" % (1 if (flags & P_LP64) else 0))
                    write_line(fp, "p_translated=%d" % (1 if (flags & P_TRANSLATED) else 0))
                    write_line(fp, "active_arch=%s" % classify(flags))

                write_line(fp)
                write_line(fp, "-- vmmap header for pid %d (best effort) --" % pid)
                rc2, vm = run(["/usr/bin/vmmap", str(pid)])
                if rc2 != 0:
                    write_line(fp, "vmmap_status=UNAVAILABLE")
                    for line in vm.splitlines()[:40]:
                        write_line(fp, line)
                else:
                    write_line(fp, "vmmap_status=OK")
                    lines = vm.splitlines()
                    interesting = []
                    for line in lines[:140]:
                        if re.search(r"(Process:|Path:|Architecture|64-bit|x86_64|i386|__TEXT)", line, re.I):
                            interesting.append(line)
                    if interesting:
                        for line in interesting[:60]:
                            write_line(fp, line)
                    else:
                        for line in lines[:40]:
                            write_line(fp, line)

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
        write_line(fp, "No process was signaled, suspended, restarted, or modified.")
        write_line(fp, "No environment variable or service configuration was changed.")
        write_line(fp, "No registration database or system file was modified.")

    print("Created: %s" % report)
    print("No PowerPC application was launched and no system file was modified.")
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
