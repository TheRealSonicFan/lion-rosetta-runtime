#!/usr/bin/python
from __future__ import print_function

import os
import re
import subprocess
import sys

DEFAULT_REPORT = "./distributed-notifications-service-namespace.txt"
ANALYZER_VERSION = "1"

PLIST_DIRS = [
    "/System/Library/LaunchDaemons",
    "/System/Library/LaunchAgents",
    "/Library/LaunchDaemons",
    "/Library/LaunchAgents",
]

BINARIES = [
    ("distnoted", "/usr/sbin/distnoted"),
    ("Foundation", "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation"),
    ("CoreFoundation", "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"),
]

MATCH_RE = re.compile(
    r"(distnoted|distributed[_ .-]*notifications?|"
    r"NSDistributedNotification|CFNotificationCenterGetDistributedCenter|"
    r"bootstrap_look_up)",
    re.I,
)


def run(cmd):
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.communicate()[0]
    except OSError as exc:
        return 127, "exec_failed: %s" % exc
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


def emit_process_state(fp):
    write_line(fp)
    write_line(fp, "== Active distnoted / launchd process state ==")

    commands = [
        ["/bin/ps", "-axo", "pid=,ppid=,uid=,command="],
        ["/bin/ps", "ax", "-o", "pid=,ppid=,command="],
    ]
    output = ""
    for cmd in commands:
        rc, out = run(cmd)
        if rc == 0:
            output = out
            break

    if not output:
        write_line(fp, "process_list_failed")
        return 0

    hits = [line for line in output.splitlines()
            if re.search(r"(^|/)(launchd|distnoted)( |$)|/usr/sbin/distnoted", line, re.I)]
    for line in hits:
        write_line(fp, line)
    if not hits:
        write_line(fp, "(none)")
    return len(hits)


def emit_launchctl_state(fp):
    write_line(fp)
    write_line(fp, "== Current launchctl namespace listing ==")
    rc, out = run(["/bin/launchctl", "list"])
    write_line(fp, "launchctl_list_rc=%d" % rc)
    if rc != 0:
        write_line(fp, out.rstrip())
        return 0

    hits = [line for line in out.splitlines() if MATCH_RE.search(line)]
    for line in hits:
        write_line(fp, line)
    if not hits:
        write_line(fp, "(no matching jobs in current launchctl namespace)")
    return len(hits)


def emit_matching_plists(fp):
    write_line(fp)
    write_line(fp, "== Matching launchd plists ==")

    scanned = 0
    matches = 0
    for directory in PLIST_DIRS:
        write_line(fp)
        write_line(fp, "-- directory: %s --" % directory)
        if not os.path.isdir(directory):
            write_line(fp, "state=MISSING")
            continue

        for name in sorted(os.listdir(directory)):
            if not name.endswith(".plist"):
                continue
            path = os.path.join(directory, name)
            scanned += 1

            rc, xml = run(["/usr/bin/plutil", "-convert", "xml1", "-o", "-", path])
            if rc != 0:
                continue
            if not MATCH_RE.search(xml) and not MATCH_RE.search(name):
                continue

            matches += 1
            write_line(fp, "plist=%s" % path)
            for line in xml.splitlines():
                write_line(fp, line)
            write_line(fp)

    write_line(fp, "plist_scanned_count=%d" % scanned)
    write_line(fp, "plist_match_count=%d" % matches)
    return scanned, matches


def emit_binary_strings(fp, label, path):
    write_line(fp)
    write_line(fp, "============================================================")
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)

    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        return 0

    write_line(fp, "sha256=%s" % sha256(path))

    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())

    rc, out = run(["/usr/bin/lipo", "-info", path])
    if out.strip():
        write_line(fp, out.rstrip())

    if label == "distnoted":
        rc, out = run(["/usr/bin/otool", "-L", path])
        write_line(fp, "-- linked libraries --")
        write_line(fp, out.rstrip())

    rc, out = run(["/usr/bin/strings", "-a", path])
    if rc != 0:
        write_line(fp, "strings_failed")
        write_line(fp, out.rstrip())
        return 0

    matches = []
    seen = set()
    for line in out.splitlines():
        if not MATCH_RE.search(line):
            continue
        if line in seen:
            continue
        seen.add(line)
        matches.append(line)

    write_line(fp, "-- distributed-notifications-related strings --")
    for line in matches:
        write_line(fp, line)
    if not matches:
        write_line(fp, "(none)")
    write_line(fp, "string_match_count=%d" % len(matches))
    return len(matches)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []

    _, product = run(["/usr/bin/sw_vers", "-productVersion"])
    _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
    _, user = run(["/usr/bin/whoami"])
    _, uid = run(["/usr/bin/id", "-u"])

    product = product.strip()
    build = build.strip()

    with open(report, "w") as fp:
        write_line(fp, "== Distributed notifications service / bootstrap namespace audit ==")
        write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        write_line(fp, "product_version=%s" % product)
        write_line(fp, "build_version=%s" % build)
        write_line(fp, "current_user=%s" % user.strip())
        write_line(fp, "current_uid=%s" % uid.strip())

        process_hits = emit_process_state(fp)
        launchctl_hits = emit_launchctl_state(fp)
        plist_scanned, plist_matches = emit_matching_plists(fp)

        binary_matches = {}
        for label, path in BINARIES:
            binary_matches[label] = emit_binary_strings(fp, label, path)

        write_line(fp)
        write_line(fp, "== Audit validation ==")

        if not (product.startswith("10.6") or product.startswith("10.7")):
            issues.append("unsupported OS baseline: %s" % product)
        if not os.path.isfile("/usr/sbin/distnoted"):
            issues.append("/usr/sbin/distnoted missing")
        if process_hits == 0:
            issues.append("no launchd/distnoted process rows captured")
        if plist_scanned == 0:
            issues.append("no launchd plists scanned")
        write_line(fp, "process_match_count=%d" % process_hits)
        write_line(fp, "launchctl_match_count=%d" % launchctl_hits)
        write_line(fp, "plist_match_count=%d" % plist_matches)
        write_line(fp, "distnoted_string_match_count=%d" %
                   binary_matches.get("distnoted", 0))
        write_line(fp, "foundation_string_match_count=%d" %
                   binary_matches.get("Foundation", 0))
        write_line(fp, "corefoundation_string_match_count=%d" %
                   binary_matches.get("CoreFoundation", 0))

        if issues:
            for issue in issues:
                write_line(fp, "validation_issue=%s" % issue)
            write_line(fp, "RESULT: FAIL")
        else:
            write_line(fp, "RESULT: PASS")

        write_line(fp)
        write_line(fp, "== Audit integrity ==")
        write_line(fp, "No PowerPC application was launched by this audit.")
        write_line(fp, "No bootstrap lookup was issued by this audit.")
        write_line(fp, "No Mach service was started, stopped, restarted, registered, or signaled.")
        write_line(fp, "No launchd plist, framework, executable, cache, or system file was modified.")
        write_line(fp, "launchctl was used only for the read-only current-namespace list query.")

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
