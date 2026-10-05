#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-registerapplication-callsite.txt"

HISERVICES = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
LAUNCHSERVICES = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
CORESERVICESD = "/System/Library/CoreServices/coreservicesd"

BINARIES = [
    ("HIServices", HISERVICES, ["i386", "ppc7400"]),
    ("LaunchServices", LAUNCHSERVICES, ["i386", "ppc7400"]),
    ("coreservicesd", CORESERVICESD, ["i386", "x86_64"]),
]

EXACT_TARGETS = {
    "HIServices": [
        "__RegisterApplication",
        "_RegisterApplication",
        "_GetCurrentProcess",
        "_GetProcessPID",
        "_GetProcessForPID",
        "_ProcessManagerLazyInitialization",
        "_IsProcessManagerInitialized",
    ],
    "LaunchServices": [
        "__LSGetCurrentApplicationASN",
        "__LSASNCreate",
        "__LSASNCreateWithPid",
        "__LSASNExtractHighAndLowParts",
        "__LSCopyApplicationInformation",
        "__LSCopyApplicationInformationItem",
        "__LSFindApplicationsItem",
        "__LSRegisterApplication",
        "__LSRegisterSelf",
    ],
    "coreservicesd": [],
}

SYMBOL_RE = re.compile(
    r"(RegisterApplication|CurrentApplicationASN|ApplicationASN|"
    r"LSASN|FindApplicationsItem|CopyApplicationInformation|"
    r"ProcessSerial|ProcessManager|GetProcess|CPS|CGS|session)",
    re.I,
)

STRING_RE = re.compile(
    r"(LSDoNotAbortIfNoASN|LSDONOTABORTIFNOASN|"
    r"get application ASN|GET ASN FROM CORESERVICES|"
    r"REGISTER PROCESS WITH CPS|Process Manager|ProcessManager|"
    r"RegisterApplication|CurrentApplicationASN|ApplicationASN|"
    r"coreservicesd|\\bASN\\b|\\bCPS\\b|WindowServer|session)",
    re.I,
)

NM_RE = re.compile(r"^\\s*([0-9A-Fa-f]+)\\s+.*\\s(\\S+)$")
INSN_RE = re.compile(r"^\\s*([0-9A-Fa-f]+)\\s+(.*)$")


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]


def write_line(fp, text=""):
    fp.write(text)
    fp.write("\n")


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc != 0:
        rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0, out


def thin_arch(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out


def parse_symbols(text):
    ordered = []
    by_name = {}
    for line in text.splitlines():
        m = NM_RE.match(line)
        if not m:
            continue
        try:
            addr = int(m.group(1), 16)
        except ValueError:
            continue
        name = m.group(2)
        ordered.append((addr, name))
        by_name[name] = addr
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        m = INSN_RE.match(line)
        if not m:
            continue
        try:
            addr = int(m.group(1), 16)
        except ValueError:
            continue
        rows.append((addr, line))
    return rows


def next_symbol_address(ordered, start):
    for addr, name in ordered:
        if addr > start:
            return addr
    return None


def emit_symbol_window(fp, rows, ordered, name, start, max_bytes=0x2000):
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


def emit_references(fp, dis_lines, name, address):
    write_line(fp)
    write_line(fp, "-- references to %s --" % name)
    refs = []
    address_forms = [
        "0x%x" % address,
        "%08x" % address,
    ]
    for line in dis_lines:
        if name in line:
            refs.append(line)
            continue
        if ("call" in line or "\tbl\t" in line or "\tb\t" in line):
            for form in address_forms:
                if form in line:
                    refs.append(line)
                    break

    write_line(fp, "reference_lines=%d" % len(refs))
    for line in refs[:120]:
        write_line(fp, line)
    if len(refs) > 120:
        write_line(fp, "additional_reference_lines_omitted=%d" % (len(refs) - 120))


def analyze_slice(fp, label, path, arch, tempdir):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
    ok, out = thin_arch(path, arch, thin)

    write_line(fp)
    write_line(fp, "== %s slice: %s ==" % (label, arch))
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        write_line(fp, out.rstrip())
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, deps = run(["/usr/bin/otool", "-L", thin])
    write_line(fp, "-- dependencies --")
    write_line(fp, deps.rstrip())

    rc, strings_out = run(["/usr/bin/strings", "-a", thin])
    write_line(fp, "-- registration/ASN strings --")
    if rc == 0:
        hits = [x for x in strings_out.splitlines() if STRING_RE.search(x)]
        for line in hits[:300]:
            write_line(fp, line)
        if len(hits) > 300:
            write_line(fp, "additional_string_hits_omitted=%d" % (len(hits) - 300))
    else:
        write_line(fp, "strings_failed")

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "-- nm failed --")
        write_line(fp, nm_out.rstrip())
        return

    write_line(fp, "-- registration/ASN symbols and imports --")
    nm_hits = [x for x in nm_out.splitlines() if SYMBOL_RE.search(x)]
    for line in nm_hits[:500]:
        write_line(fp, line)
    if len(nm_hits) > 500:
        write_line(fp, "additional_nm_hits_omitted=%d" % (len(nm_hits) - 500))

    ordered, by_name = parse_symbols(nm_out)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "-- disassembly failed --")
        write_line(fp, dis_out.rstrip())
        return

    rows = parse_instructions(dis_out)
    dis_lines = dis_out.splitlines()

    targets = []
    for name in EXACT_TARGETS.get(label, []):
        if name in by_name:
            targets.append((name, by_name[name]))

    for addr, name in ordered:
        if SYMBOL_RE.search(name):
            item = (name, addr)
            if item not in targets:
                targets.append(item)
        if len(targets) >= 80:
            break

    write_line(fp, "selected_symbol_windows=%d" % len(targets))
    for name, addr in targets:
        emit_symbol_window(fp, rows, ordered, name, addr)

    if label == "HIServices":
        for name in ["__RegisterApplication", "_RegisterApplication"]:
            if name in by_name:
                emit_references(fp, dis_lines, name, by_name[name])


def analyze_binary(fp, label, path, arches, tempdir):
    write_line(fp)
    write_line(fp, "============================================================")
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)

    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        return

    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    write_line(fp, out.rstrip())

    for arch in arches:
        analyze_slice(fp, label, path, arch, tempdir)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-registerapplication-audit.")

    try:
        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])

            write_line(fp, "== Process Manager RegisterApplication/ASN callsite audit ==")
            write_line(fp, "product_version=%s" % product.strip())
            write_line(fp, "build_version=%s" % build.strip())

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            for label, path, arches in BINARIES:
                analyze_binary(fp, label, path, arches, tempdir)

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No LaunchServices or Process Manager registration state was modified by this audit.")
            write_line(fp, "No system file was modified by this audit.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        print("No PowerPC application was launched and no system file was modified.")
        return 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
