#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./distributed-notifications-protocol-differential.txt"
ANALYZER_VERSION = "1"

COREFOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
DISTNOTED = "/usr/sbin/distnoted"

SNOW_SERVICE = "com.apple.distributed_notifications.2"
LION_SELECTED_SERVICE = "com.apple.distributed_notifications@Uv3"

PUBLIC_CF_TARGETS = [
    "_CFNotificationCenterGetDistributedCenter",
    "_CFNotificationCenterAddObserver",
    "_CFNotificationCenterRemoveObserver",
    "_CFNotificationCenterRemoveEveryObserver",
    "_CFNotificationCenterPostNotification",
    "_CFNotificationCenterPostNotificationWithOptions",
]

FOCUS_RE = re.compile(
    r"(CFXNotification|CFNotificationCenter|distributed[_ .-]*notification|"
    r"bootstrap_look_up|mach_msg|mach_port_|mig_|xpc_|CFPropertyList|"
    r"CFData|CFDictionary|CFArray|CFString)",
    re.I,
)

TRANSPORT_RE = re.compile(
    r"(bootstrap_look_up2?|mach_msg|mig_|xpc_connection_|xpc_dictionary_|"
    r"xpc_array_|xpc_data_|distributed[_ .-]*notification)",
    re.I,
)

CF_PRIVATE_RE = re.compile(r"CFXNotification", re.I)
DISTNOTED_SYMBOL_RE = re.compile(
    r"(distnot|notification|xpc|mach|message|connection|listener)",
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
        return True
    rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0


def thin_arch(src, arch, dst):
    if not verify_arch(src, arch):
        return False
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0


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


def parse_nm_text_symbol_name(line):
    marker = "(__TEXT,__text)"
    if marker not in line:
        return None
    tail = line.split(marker, 1)[1].strip()
    prefixes = [
        "non-external (was a private external) ",
        "non-external ",
        "external ",
    ]
    for prefix in prefixes:
        if tail.startswith(prefix):
            return tail[len(prefix):].strip()
    return tail if tail else None


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
        is_text = "(__TEXT,__text)" in line
        if is_text:
            name = parse_nm_text_symbol_name(line)
            if not name:
                continue
        else:
            name = parts[-1]
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


def next_symbol_address(ordered_text, start):
    for addr, name in ordered_text:
        if addr > start:
            return addr
    return None


def emit_symbol_window(fp, rows, ordered_text, name, start, max_bytes=0x6000):
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


def emit_context_hits(fp, lines, regex, radius=12, max_hits=160):
    write_line(fp)
    write_line(fp, "-- transport callsite contexts --")
    hits = [i for i, line in enumerate(lines) if regex.search(line)]
    write_line(fp, "transport_hit_count=%d" % len(hits))
    emitted = 0
    last_end = -1
    for idx in hits:
        if emitted >= max_hits:
            break
        lo = max(0, idx - radius)
        hi = min(len(lines), idx + radius + 1)
        if lo <= last_end:
            lo = last_end + 1
        if lo >= hi:
            continue
        write_line(fp, "context_hit_line=%d" % (idx + 1))
        for j in range(lo, hi):
            write_line(fp, lines[j])
        last_end = hi - 1
        emitted += 1
    if len(hits) > emitted:
        write_line(fp, "additional_transport_hits_omitted=%d" % (len(hits) - emitted))


def analyze_binary_slice(fp, label, path, arch, tempdir, evidence):
    thin = os.path.join(tempdir, "%s.%s" % (label, arch))
    ok = thin_arch(path, arch, thin)
    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    evidence[(label, arch, "slice")] = ok
    if not ok:
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
    if rc != 0:
        rc, strings_out = run(["/usr/bin/strings", thin])
    write_line(fp, "-- focused strings --")
    if rc == 0:
        focused = [line for line in strings_out.splitlines() if FOCUS_RE.search(line)]
        for line in focused[:1400]:
            write_line(fp, line)
        if len(focused) > 1400:
            write_line(fp, "additional_string_hits_omitted=%d" % (len(focused) - 1400))
        evidence[(label, arch, "snow_service")] = SNOW_SERVICE in strings_out
        evidence[(label, arch, "lion_service")] = LION_SELECTED_SERVICE in strings_out

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    write_line(fp, "-- focused symbols/imports --")
    if rc != 0:
        write_line(fp, "nm_failed")
        write_line(fp, nm_out.rstrip())
        return

    nm_lines = nm_out.splitlines()
    nm_hits = [line for line in nm_lines if FOCUS_RE.search(line)]
    for line in nm_hits[:1800]:
        write_line(fp, line)
    if len(nm_hits) > 1800:
        write_line(fp, "additional_nm_hits_omitted=%d" % (len(nm_hits) - 1800))

    evidence[(label, arch, "nm_bootstrap")] = "bootstrap_look_up" in nm_out
    evidence[(label, arch, "nm_mach_msg")] = "_mach_msg" in nm_out
    evidence[(label, arch, "nm_xpc_create")] = "_xpc_connection_create" in nm_out
    evidence[(label, arch, "nm_xpc_send")] = (
        "_xpc_connection_send_message" in nm_out or
        "_xpc_connection_send_message_with_reply" in nm_out
    )

    ordered, by_name = parse_symbols(nm_out)
    ordered_text = [(addr, name) for addr, name, line, is_text in ordered if is_text]

    for target in PUBLIC_CF_TARGETS:
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
    emit_context_hits(fp, dis_lines, TRANSPORT_RE)

    targets = []
    if label == "CoreFoundation":
        for target in PUBLIC_CF_TARGETS:
            for addr in by_name.get(target, []):
                targets.append((addr, target))
        for addr, name in ordered_text:
            if CF_PRIVATE_RE.search(name):
                targets.append((addr, name))
    else:
        for addr, name in ordered_text:
            if DISTNOTED_SYMBOL_RE.search(name):
                targets.append((addr, name))

    seen = set()
    selected = []
    for addr, name in sorted(targets):
        key = (addr, name)
        if key in seen:
            continue
        seen.add(key)
        selected.append(key)

    write_line(fp)
    write_line(fp, "-- selected protocol symbols --")
    write_line(fp, "selected_symbol_count=%d" % len(selected))
    for addr, name in selected[:100]:
        write_line(fp, "0x%x %s" % (addr, name))
    if len(selected) > 100:
        write_line(fp, "additional_selected_symbols_omitted=%d" % (len(selected) - 100))

    for addr, name in selected[:100]:
        emit_symbol_window(fp, rows, ordered_text, name, addr)


def validate(product, evidence, issues):
    if product == "10.6.8":
        cf_arch = "ppc7400"
        server_arch = "i386"
        if not evidence.get(("CoreFoundation", cf_arch, "slice"), False):
            issues.append("Snow CoreFoundation PPC slice missing")
        if not evidence.get(("distnoted", server_arch, "slice"), False):
            issues.append("Snow distnoted i386 slice missing")
        if not evidence.get(("CoreFoundation", cf_arch, "snow_service"), False):
            issues.append("Snow legacy distributed-notifications service string missing")
        if not evidence.get(("CoreFoundation", cf_arch, "nm_bootstrap"), False):
            issues.append("Snow PPC CoreFoundation bootstrap lookup import missing")
        if not evidence.get(("CoreFoundation", cf_arch, "nm_mach_msg"), False):
            issues.append("Snow PPC CoreFoundation mach_msg import missing")
        for target in PUBLIC_CF_TARGETS:
            if not evidence.get(("CoreFoundation", cf_arch, "symbol:" + target), False):
                issues.append("Snow PPC CoreFoundation target missing: %s" % target)
    elif product == "10.7.5":
        cf_arch = "i386"
        server_arch = "i386"
        if not evidence.get(("CoreFoundation", cf_arch, "slice"), False):
            issues.append("Lion CoreFoundation i386 slice missing")
        if not evidence.get(("distnoted", server_arch, "slice"), False):
            issues.append("Lion distnoted i386 slice missing")
        if not evidence.get(("CoreFoundation", cf_arch, "lion_service"), False):
            issues.append("Lion selected @Uv3 service string missing from CoreFoundation")
        if not evidence.get(("distnoted", server_arch, "lion_service"), False):
            issues.append("Lion selected @Uv3 service string missing from distnoted")
        if not evidence.get(("CoreFoundation", cf_arch, "nm_xpc_create"), False):
            issues.append("Lion CoreFoundation xpc_connection_create import missing")
        if not evidence.get(("CoreFoundation", cf_arch, "nm_xpc_send"), False):
            issues.append("Lion CoreFoundation XPC send import missing")
        for target in PUBLIC_CF_TARGETS:
            if not evidence.get(("CoreFoundation", cf_arch, "symbol:" + target), False):
                issues.append("Lion CoreFoundation target missing: %s" % target)
    else:
        issues.append("unsupported OS baseline: %s" % product)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="distnotify-protocol-diff.")
    evidence = {}
    issues = []

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        with open(report, "w") as fp:
            write_line(fp, "== Distributed notifications protocol differential audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "selected_lion_service=%s" % LION_SELECTED_SERVICE)
            write_line(fp, "selection_basis=native Lion CF trace before retired interposer recursion")

            binaries = [
                ("CoreFoundation", COREFOUNDATION),
                ("distnoted", DISTNOTED),
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

                arches = ["ppc7400", "i386"] if product == "10.6.8" else ["i386"]
                for arch in arches:
                    analyze_binary_slice(fp, label, path, arch, tempdir, evidence)

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
            write_line(fp, "No CoreFoundation notification-center API was called dynamically.")
            write_line(fp, "No bootstrap lookup, Mach request, or XPC request was issued by this audit.")
            write_line(fp, "No distributed notification was registered, posted, removed, or delivered intentionally.")
            write_line(fp, "No launchd or distnoted process was started, stopped, restarted, signaled, or modified.")
            write_line(fp, "No framework, executable, launchd plist, Rosetta component, cache, or kernel was modified.")
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
