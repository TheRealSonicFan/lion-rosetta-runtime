#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./distributed-notifications-bridge-preflight.txt"
ANALYZER_VERSION = "1"

COREFOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
LIBSYSTEM_CANDIDATES = [
    "/usr/lib/libSystem.B.dylib",
    "/usr/lib/libSystem.dylib",
]
LIBXPC_CANDIDATES = [
    "/usr/lib/system/libxpc.dylib",
    "/usr/lib/libxpc.dylib",
]

SNOW_TARGETS = [
    "_CFNotificationCenterAddObserver",
    "_CFNotificationCenterPostNotificationWithOptions",
    "__CFXNotificationPostNotification",
    "__CFXNotificationRegister",
    "__CFXNotificationUnregister",
    "__CFXNotificationSetSuspended",
    "__CFXNotificationResetSessionForTask",
    "___CFXNotificationHandleMessage",
    "___CFXNotificationReceiveFromClient",
]

LION_TARGETS = [
    "_CFNotificationCenterAddObserver",
    "_CFNotificationCenterPostNotificationWithOptions",
    "__CFXNotificationRegisterObserver",
    "__CFXNotificationPost",
    "__CFXNotificationRemoveObservers",
    "__CFXNotificationSetSuspended",
    "__CFXNotificationResetSessionForTask",
    "_____CFXNotificationCenterSetupConnection_block_invoke_1",
]

FOCUS_RE = re.compile(
    r"(message_type|post_token|register|unregister|suspend|unsuspend|"
    r"session_reset|i_am_loginwindow|registrations|immediately|sux|"
    r"behavior|counter|entry|entries|method|version|options|token|tokens|"
    r"name|object|userinfo|sessionid|CFDictionary|CFNumber|xpc_|mach_msg)",
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


def line(fp, value=""):
    fp.write(value)
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


def parse_nm_text_symbol_name(raw):
    marker = "(__TEXT,__text)"
    if marker not in raw:
        return None
    tail = raw.split(marker, 1)[1].strip()
    prefixes = [
        "non-external (was a private external) ",
        "non-external ",
        "external ",
    ]
    for prefix in prefixes:
        if tail.startswith(prefix):
            return tail[len(prefix):].strip()
    return tail if tail else None


def parse_text_symbols(text):
    ordered = []
    by_name = {}
    for raw in text.splitlines():
        parts = raw.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in raw:
            continue
        addr = parse_hex_token(parts[0])
        name = parse_nm_text_symbol_name(raw)
        if addr is None or not name:
            continue
        ordered.append((addr, name))
        by_name.setdefault(name, []).append(addr)
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, raw))
    return rows


def next_symbol(ordered, start):
    for addr, name in ordered:
        if addr > start:
            return addr
    return None


def window_rows(rows, ordered, start, max_bytes=0x9000):
    end = start + max_bytes
    nxt = next_symbol(ordered, start)
    if nxt is not None:
        end = min(end, nxt)
    result = []
    for addr, raw in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        result.append((addr, raw))
    return result


def emit_target_windows(fp, thin, targets, evidence):
    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        line(fp, "nm_failed")
        return
    ordered, by_name = parse_text_symbols(nm_out)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        line(fp, "disassembly_failed")
        return
    rows = parse_instructions(dis_out)

    line(fp)
    line(fp, "-- bridge-preflight target inventory --")
    for target in targets:
        count = len(by_name.get(target, []))
        line(fp, "%s count=%d" % (target, count))
        evidence["target:" + target] = count > 0

    for target in targets:
        for start in sorted(by_name.get(target, [])):
            window = window_rows(rows, ordered, start)
            line(fp)
            line(fp, "-- exact target: %s --" % target)
            line(fp, "symbol_address=0x%x" % start)
            line(fp, "instruction_lines=%d" % len(window))
            for addr, raw in window:
                line(fp, raw)
            line(fp, "-- focused bridge-semantics lines: %s --" % target)
            hits = 0
            for idx, pair in enumerate(window):
                addr, raw = pair
                if FOCUS_RE.search(raw):
                    lo = max(0, idx - 8)
                    hi = min(len(window), idx + 9)
                    line(fp, "focus_hit_address=0x%x" % addr)
                    for j in range(lo, hi):
                        line(fp, window[j][1])
                    hits += 1
                    if hits >= 80:
                        break
            line(fp, "focus_hit_count=%d" % hits)


def focused_nm_symbols(path):
    rc, out = run(["/usr/bin/nm", "-g", path])
    if rc != 0:
        rc, out = run(["/usr/bin/nm", path])
    if rc != 0:
        return "", False, False
    rows = []
    create = False
    send = False
    for raw in out.splitlines():
        if "_xpc_" in raw or "_mach_msg" in raw or "bootstrap_" in raw:
            rows.append(raw)
        if "_xpc_connection_create" in raw:
            create = True
        if ("_xpc_connection_send_message" in raw or
                "_xpc_connection_send_message_with_reply" in raw):
            send = True
    return "\n".join(rows), create, send


def inspect_library(fp, path, label, tempdir, evidence):
    line(fp)
    line(fp, "== Library capability: %s ==" % label)
    line(fp, "path=%s" % path)
    exists = os.path.exists(path)
    line(fp, "exists=%s" % ("YES" if exists else "NO"))
    if not exists:
        return

    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/lipo", "-info", path])
    if rc != 0:
        rc, out = run(["/usr/bin/file", path])
    line(fp, "architecture_info=%s" % out.strip().replace("\n", " | "))

    for arch in ("ppc7400", "i386", "x86_64"):
        present = verify_arch(path, arch)
        line(fp, "arch_%s=%s" % (arch, "YES" if present else "NO"))
        evidence[(label, arch, "present")] = present
        if not present:
            continue

        thin = os.path.join(
            tempdir,
            re.sub(r"[^A-Za-z0-9_.-]", "_", label) + "." + arch)
        if not thin_arch(path, arch, thin):
            line(fp, "thin_%s=FAIL" % arch)
            continue
        line(fp, "thin_%s=YES" % arch)
        symbols, has_create, has_send = focused_nm_symbols(thin)
        line(fp, "xpc_connection_create_%s=%s" %
             (arch, "YES" if has_create else "NO"))
        line(fp, "xpc_connection_send_%s=%s" %
             (arch, "YES" if has_send else "NO"))
        evidence[(label, arch, "xpc_create")] = has_create
        evidence[(label, arch, "xpc_send")] = has_send
        if symbols:
            line(fp, "-- focused exports/imports: %s %s --" % (label, arch))
            for raw in symbols.splitlines():
                line(fp, raw)


def inspect_corefoundation(fp, arch, tempdir, targets, evidence):
    line(fp)
    line(fp, "== CoreFoundation bridge-preflight slice: %s ==" % arch)
    ok = os.path.isfile(COREFOUNDATION) and verify_arch(COREFOUNDATION, arch)
    line(fp, "slice_present=%s" % ("YES" if ok else "NO"))
    evidence["cf_slice"] = ok
    if not ok:
        return

    thin = os.path.join(tempdir, "CoreFoundation." + arch)
    if not thin_arch(COREFOUNDATION, arch, thin):
        line(fp, "thin=FAIL")
        return
    line(fp, "thin=YES")
    line(fp, "slice_sha256=%s" % sha256(thin))

    symbols, has_create, has_send = focused_nm_symbols(thin)
    evidence["cf_xpc_create"] = has_create
    evidence["cf_xpc_send"] = has_send
    line(fp, "corefoundation_xpc_connection_create=%s" %
         ("YES" if has_create else "NO"))
    line(fp, "corefoundation_xpc_connection_send=%s" %
         ("YES" if has_send else "NO"))
    if symbols:
        line(fp, "-- CoreFoundation focused imports --")
        for raw in symbols.splitlines():
            line(fp, raw)

    emit_target_windows(fp, thin, targets, evidence)


def candidate_xpc_surface(evidence):
    for label in ("libSystem.B", "libSystem", "libxpc.system", "libxpc"):
        if (evidence.get((label, "ppc7400", "present"), False) and
                evidence.get((label, "ppc7400", "xpc_create"), False) and
                evidence.get((label, "ppc7400", "xpc_send"), False)):
            return True
    return False


def validate(product, evidence, targets, issues):
    if not evidence.get("cf_slice", False):
        issues.append("required CoreFoundation slice missing")
    for target in targets:
        if not evidence.get("target:" + target, False):
            issues.append("required CoreFoundation target missing: %s" % target)

    if product == "10.7.5":
        if not evidence.get("cf_xpc_create", False):
            issues.append("Lion CoreFoundation XPC create import missing")
        if not evidence.get("cf_xpc_send", False):
            issues.append("Lion CoreFoundation XPC send import missing")


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="distnotify-bridge-preflight.")
    issues = []
    evidence = {}

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8":
            cf_arch = "ppc7400"
            targets = SNOW_TARGETS
        elif product == "10.7.5":
            cf_arch = "i386"
            targets = LION_TARGETS
        else:
            cf_arch = "i386"
            targets = []
            issues.append("unsupported OS baseline: %s" % product)

        with open(report, "w") as fp:
            line(fp, "== Distributed notifications bridge preflight audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "selected_lion_service=com.apple.distributed_notifications@Uv3")
            line(fp, "abi_provenance=protocol-abi analyzer-v2 PASS on Snow and Lion")
            line(fp, "objective=choose callable XPC bridge architecture and close option/token semantics")

            inspect_corefoundation(fp, cf_arch, tempdir, targets, evidence)

            for path, label in (
                    (LIBSYSTEM_CANDIDATES[0], "libSystem.B"),
                    (LIBSYSTEM_CANDIDATES[1], "libSystem"),
                    (LIBXPC_CANDIDATES[0], "libxpc.system"),
                    (LIBXPC_CANDIDATES[1], "libxpc")):
                inspect_library(fp, path, label, tempdir, evidence)

            ppc_xpc = candidate_xpc_surface(evidence)
            line(fp)
            line(fp, "== Bridge architecture discriminator ==")
            line(fp, "ppc_callable_xpc_surface=%s" %
                 ("YES" if ppc_xpc else "NO"))
            if ppc_xpc:
                line(fp, "candidate_bridge_architecture=in-process PPC bridge may be linkable; review exact provider before implementation")
            else:
                line(fp, "candidate_bridge_architecture=no demonstrated PPC XPC provider; native i386 broker/helper is the leading architecture")
            line(fp, "session_reset_scope=Lion native path is loginwindow-specific; ordinary-client proof must reject rather than fabricate it")
            line(fp, "token_mapping_candidate=legacy entry/counter state <-> bridge-owned v3 token")
            line(fp, "unregister_mapping_candidate=legacy entries array -> stored v3 tokens array")
            line(fp, "callback_mapping_candidate=v3 post_token -> legacy post dictionary using stored counter/entry")
            line(fp, "remaining_semantic_checks=register behavior->options, post immediately/all-session->options, legacy sux handling")
            line(fp, "mapping_status=PREFLIGHT_ONLY_DO_NOT_BUILD_BRIDGE_YET")

            validate(product, evidence, targets, issues)

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC application was launched by this audit.")
            line(fp, "No XPC connection or message was created or sent.")
            line(fp, "No bootstrap lookup or Mach request was issued.")
            line(fp, "No distributed notification was registered, posted, removed, suspended, or delivered.")
            line(fp, "No launchd or distnoted process was started, stopped, restarted, signaled, or modified.")
            line(fp, "No framework, executable, launchd plist, Rosetta component, cache, or kernel was modified.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

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
