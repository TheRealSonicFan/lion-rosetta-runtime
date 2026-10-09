#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./distributed-notifications-client-service-selection.txt"
ANALYZER_VERSION = "2"

COREFOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
FOUNDATION = "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation"
ARCHES = ["i386", "x86_64", "ppc7400"]

SNOW_SERVICE = "com.apple.distributed_notifications.2"
LION_USER_SERVICE = "com.apple.distributed_notifications@Uv3"
LION_ALL_SESSIONS_SERVICE = "com.apple.distributed_notifications@1v3"
LION_DAEMON_SERVICE = "com.apple.distributed_notifications@0v3"

CF_EXACT_TARGETS = [
    "_CFNotificationCenterGetDistributedCenter",
    "___CFNotificationCenterGetDistributedCenter_block_invoke_1",
    "_CFNotificationCenterAddObserver",
    "_CFNotificationCenterRemoveObserver",
    "_CFNotificationCenterRemoveEveryObserver",
    "_CFNotificationCenterPostNotification",
    "_CFNotificationCenterPostNotificationWithOptions",
]

FOUNDATION_EXACT_TARGETS = [
    "+[NSDistributedNotificationCenter defaultCenter]",
    "+[NSDistributedNotificationCenter notificationCenterForType:]",
]

FOCUS_RE = re.compile(
    r"(CFNotificationCenter|DistributedNotification|distributed_notifications|"
    r"distributed-notification|bootstrap_look_up|bootstrap_look_up2|"
    r"mach_msg|mach_port_|mig_|xpc_|CFMachPort|CFMessagePort)",
    re.I,
)

SERVICE_RE = re.compile(
    r"com\.apple\.distributed_notifications(?:\.2|@[01U]v3)",
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
            by_name.setdefault(name, []).append(addr)
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
    end = start + max_bytes
    nxt = next_symbol_address(ordered_text, start)
    if nxt is not None:
        end = min(end, nxt)

    write_line(fp)
    write_line(fp, "-- symbol window: %s --" % name)
    write_line(fp, "symbol_address=0x%x" % start)

    count = 0
    for addr, line in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        write_line(fp, line)
        count += 1
    write_line(fp, "instruction_lines=%d" % count)


def addressed_cstrings(thin):
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        return rc, out, []

    rows = []
    for line in out.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        rows.append((addr, parts[1], line))
    return rc, out, rows


def emit_service_references(fp, dis_lines, cstring_rows):
    write_line(fp)
    write_line(fp, "-- distributed-notification service cstrings and static references --")
    service_rows = [(addr, text, raw) for addr, text, raw in cstring_rows
                    if SERVICE_RE.search(text)]

    if not service_rows:
        write_line(fp, "service_cstring_count=0")
        return []

    write_line(fp, "service_cstring_count=%d" % len(service_rows))
    found = []
    for addr, text, raw in service_rows:
        found.append(text)
        write_line(fp, "cstring_address=0x%x value=%s" % (addr, text))
        forms = [
            "0x%x" % addr,
            "%08x" % addr,
            "%016x" % addr,
        ]
        refs = []
        for line in dis_lines:
            lower = line.lower()
            if text in line:
                refs.append(line)
                continue
            if any(form.lower() in lower for form in forms):
                refs.append(line)
        write_line(fp, "reference_lines=%d" % len(refs))
        for line in refs[:300]:
            write_line(fp, line)
        if len(refs) > 300:
            write_line(fp, "additional_reference_lines_omitted=%d" %
                       (len(refs) - 300))
    return found


def analyze_slice(fp, label, path, arch, tempdir, required, evidence):
    thin = os.path.join(tempdir, "%s.%s" % (label, arch))
    ok, out = thin_arch(path, arch, thin)

    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        if required:
            evidence[(label, arch, "slice")] = False
        return

    evidence[(label, arch, "slice")] = True
    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, out = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, out.rstrip())

    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
    if rc != 0:
        rc, strings_out = run(["/usr/bin/strings", thin])
    write_line(fp, "-- focused strings --")
    if rc == 0:
        focused = [line for line in strings_out.splitlines()
                   if FOCUS_RE.search(line) or SERVICE_RE.search(line)]
        for line in focused[:800]:
            write_line(fp, line)
        if len(focused) > 800:
            write_line(fp, "additional_string_hits_omitted=%d" %
                       (len(focused) - 800))
        for service in [SNOW_SERVICE, LION_USER_SERVICE,
                        LION_ALL_SESSIONS_SERVICE, LION_DAEMON_SERVICE]:
            if service in strings_out:
                evidence[(label, arch, "string:" + service)] = True
        if "notificationCenterForType:" in strings_out:
            evidence[(label, arch, "foundation_type_selector")] = True
    else:
        write_line(fp, "strings_failed")

    rc, cstring_out, cstring_rows = addressed_cstrings(thin)
    write_line(fp, "-- addressed focused cstrings --")
    if rc == 0:
        hits = [raw for addr, text, raw in cstring_rows
                if FOCUS_RE.search(text) or SERVICE_RE.search(text)]
        for line in hits[:800]:
            write_line(fp, line)
        if len(hits) > 800:
            write_line(fp, "additional_addressed_cstring_hits_omitted=%d" %
                       (len(hits) - 800))
    else:
        write_line(fp, "otool_cstring_dump_failed")
        write_line(fp, cstring_out.rstrip())

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    write_line(fp, "-- focused symbols/imports --")
    if rc != 0:
        write_line(fp, "nm_failed")
        write_line(fp, nm_out.rstrip())
        return

    nm_hits = [line for line in nm_out.splitlines() if FOCUS_RE.search(line)]
    for line in nm_hits[:1400]:
        write_line(fp, line)
    if len(nm_hits) > 1400:
        write_line(fp, "additional_nm_hits_omitted=%d" % (len(nm_hits) - 1400))

    ordered, by_name = parse_symbols(nm_out)
    ordered_text = text_symbols(ordered)

    if label == "CoreFoundation":
        for target in CF_EXACT_TARGETS:
            if by_name.get(target):
                evidence[(label, arch, "symbol:" + target)] = True
    elif label == "Foundation":
        for target in FOUNDATION_EXACT_TARGETS:
            if by_name.get(target):
                evidence[(label, arch, "symbol:" + target)] = True

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    write_line(fp, "-- disassembly summary --")
    if rc != 0:
        write_line(fp, "disassembly_failed")
        write_line(fp, dis_out.rstrip())
        return

    rows = parse_instructions(dis_out)
    dis_lines = dis_out.splitlines()
    write_line(fp, "parsed_text_symbols=%d" % len(ordered_text))
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))

    service_values = emit_service_references(fp, dis_lines, cstring_rows)
    for value in service_values:
        evidence[(label, arch, "addressed:" + value)] = True

    write_line(fp)
    write_line(fp, "-- focused disassembly lines --")
    focused_dis = [line for line in dis_lines if FOCUS_RE.search(line)]
    for line in focused_dis[:1800]:
        write_line(fp, line)
    if len(focused_dis) > 1800:
        write_line(fp, "additional_focused_disassembly_lines_omitted=%d" %
                   (len(focused_dis) - 1800))

    if label == "CoreFoundation":
        exact_targets = CF_EXACT_TARGETS
    elif label == "Foundation":
        exact_targets = FOUNDATION_EXACT_TARGETS
    else:
        exact_targets = []

    for target in exact_targets:
        addrs = sorted(by_name.get(target, []))
        write_line(fp)
        write_line(fp, "-- exact target: %s count=%d --" %
                   (target, len(addrs)))
        for addr in addrs:
            emit_symbol_window(fp, rows, ordered_text, target, addr)


def validate(product, evidence, issues):
    if product == "10.6.8":
        arch = "ppc7400"
        if not evidence.get(("CoreFoundation", arch, "slice"), False):
            issues.append("Snow CoreFoundation PPC slice missing")
        if not evidence.get(("Foundation", arch, "slice"), False):
            issues.append("Snow Foundation PPC slice missing")
        if not evidence.get(("CoreFoundation", arch,
                             "string:" + SNOW_SERVICE), False):
            issues.append("Snow legacy distributed-notifications service string missing")
        if not evidence.get(("CoreFoundation", arch,
                             "symbol:_CFNotificationCenterGetDistributedCenter"), False):
            issues.append("Snow CFNotificationCenterGetDistributedCenter symbol missing")
        if not evidence.get(("Foundation", arch,
                             "foundation_type_selector"), False):
            issues.append("Snow Foundation notificationCenterForType selector missing")
        for target in FOUNDATION_EXACT_TARGETS:
            if not evidence.get(("Foundation", arch,
                                 "symbol:" + target), False):
                issues.append("Snow Foundation exact target missing: %s" % target)
    elif product == "10.7.5":
        arch = "i386"
        if not evidence.get(("CoreFoundation", arch, "slice"), False):
            issues.append("Lion CoreFoundation i386 slice missing")
        if not evidence.get(("Foundation", arch, "slice"), False):
            issues.append("Lion Foundation i386 slice missing")
        for service in [LION_USER_SERVICE, LION_ALL_SESSIONS_SERVICE]:
            if not evidence.get(("CoreFoundation", arch,
                                 "string:" + service), False):
                issues.append("Lion CoreFoundation service string missing: %s" %
                              service)
        if not evidence.get(("CoreFoundation", arch,
                             "symbol:_CFNotificationCenterGetDistributedCenter"), False):
            issues.append("Lion CFNotificationCenterGetDistributedCenter symbol missing")
        if not evidence.get(("CoreFoundation", arch,
                             "symbol:___CFNotificationCenterGetDistributedCenter_block_invoke_1"), False):
            issues.append("Lion distributed-center initializer block missing")
        if not evidence.get(("Foundation", arch,
                             "foundation_type_selector"), False):
            issues.append("Lion Foundation notificationCenterForType selector missing")
        for target in FOUNDATION_EXACT_TARGETS:
            if not evidence.get(("Foundation", arch,
                                 "symbol:" + target), False):
                issues.append("Lion Foundation exact target missing: %s" % target)
    else:
        issues.append("unsupported OS baseline: %s" % product)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="distnotify-client-selection.")
    issues = []
    evidence = {}

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        with open(report, "w") as fp:
            write_line(fp, "== Distributed notifications client service-selection audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)

            binaries = [
                ("CoreFoundation", COREFOUNDATION),
                ("Foundation", FOUNDATION),
            ]

            for label, path in binaries:
                write_line(fp)
                write_line(fp, "============================================================")
                write_line(fp, "== %s ==" % label)
                write_line(fp, "path=%s" % path)
                if not os.path.isfile(path):
                    write_line(fp, "state=MISSING")
                    issues.append("%s binary missing" % label)
                    continue

                write_line(fp, "sha256=%s" % sha256(path))
                rc, out = run(["/usr/bin/file", path])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", path])
                write_line(fp, out.rstrip())

                for arch in ARCHES:
                    required = (
                        (product == "10.6.8" and arch == "ppc7400") or
                        (product == "10.7.5" and arch == "i386")
                    )
                    analyze_slice(fp, label, path, arch, tempdir,
                                  required, evidence)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            validate(product, evidence, issues)

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No bootstrap lookup or Mach request was issued by this audit.")
            write_line(fp, "No distributed notification was registered, posted, or removed.")
            write_line(fp, "No launchd or distnoted process was started, stopped, restarted, or signaled.")
            write_line(fp, "No framework, launchd plist, Rosetta component, cache, or system file was modified.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        print("No PowerPC application was launched and no system state was modified.")
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
