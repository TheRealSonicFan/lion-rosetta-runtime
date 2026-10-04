#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./launchservices-ppc-gate-static.txt"

BINARIES = [
    ("LaunchServices", "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"),
    ("CarbonCore", "/System/Library/Frameworks/CoreServices.framework/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"),
    ("coreservicesd", "/System/Library/CoreServices/coreservicesd"),
    ("lsregister", "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"),
    ("open", "/usr/bin/open"),
]

TARGET_SYMBOLS = [
    "_LSBundleCopyArchitecturesAvailable",
    "_LSBundleCopyArchitecturesValidOnCurrentSystem",
    "_LSGetCPUArchitecture",
    "_LSGetVersionForArchitecture",
    "_LSAppMeetsRosettaRequirement",
    "__ZL15_LSAppCheckTypePK12LSBundleDataPKvl",
    "__ZL21_LSGetArchFlagsForURLPK7__CFURL",
    "__ZL28_LSAppCheckDictionaryVersionPK14__CFDictionaryP9LSContextP6FSNodejl",
]

STRING_RE = re.compile(
    r"(rosetta|oah|powerpc|ppc|translate|RosettaRequirements|NoRosetta|unsupported-format|archhandler)",
    re.I,
)

NM_RE = re.compile(
    r"(rosetta|oah|powerpc|ppc|translate|architecture|sysctl|gestalt|LSAppCheck|LSBundleCopyArchitectures)",
    re.I,
)

DISASM_MATCH_RE = re.compile(r"(ffffd657|d657|10665)", re.I)

ERROR32 = 0xffffd657
ERROR_BYTES = struct.pack("<I", ERROR32)


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0:
        return "ERROR"
    return out.split()[0]


def write_line(fp, text=""):
    fp.write(text)
    fp.write("\n")


def thin_i386(src, dst):
    rc, out = run(["/usr/bin/lipo", src, "-verify_arch", "i386"])
    if rc != 0:
        rc, out = run(["/usr/bin/lipo", "-verify_arch", "i386", src])
    if rc != 0:
        return False, out

    rc, out = run(["/usr/bin/lipo", src, "-thin", "i386", "-output", dst])
    return rc == 0, out


def raw_occurrences(path, needle):
    data = open(path, "rb").read()
    offsets = []
    pos = 0
    while True:
        idx = data.find(needle, pos)
        if idx < 0:
            break
        offsets.append(idx)
        pos = idx + 1
    return offsets


def parse_nm_symbols(nm_text):
    symbols = {}
    for line in nm_text.splitlines():
        m = re.match(r"^([0-9A-Fa-f]+)\s+.*\s(\S+)$", line)
        if not m:
            continue
        try:
            addr = int(m.group(1), 16)
        except ValueError:
            continue
        name = m.group(2)
        symbols[name] = addr
    return symbols


def parse_disassembly(dis_text):
    rows = []
    for line in dis_text.splitlines():
        m = re.match(r"^\s*([0-9A-Fa-f]+)\s+(.*)$", line)
        if m:
            try:
                addr = int(m.group(1), 16)
            except ValueError:
                continue
            rows.append((addr, line))
    return rows


def print_context(fp, lines, index, before=10, after=16):
    start = max(0, index - before)
    end = min(len(lines), index + after + 1)
    for i in range(start, end):
        write_line(fp, lines[i])


def disassembly_error_context(fp, dis_text):
    lines = dis_text.splitlines()
    hits = []
    for i, line in enumerate(lines):
        if DISASM_MATCH_RE.search(line):
            hits.append(i)

    write_line(fp, "textual_error_constant_hits=%d" % len(hits))
    for n, idx in enumerate(hits[:24]):
        write_line(fp, "-- error constant context %d --" % (n + 1))
        print_context(fp, lines, idx)
    if len(hits) > 24:
        write_line(fp, "additional_error_constant_contexts_omitted=%d" % (len(hits) - 24))


def symbol_windows(fp, nm_text, dis_text):
    syms = parse_nm_symbols(nm_text)
    rows = parse_disassembly(dis_text)

    for target in TARGET_SYMBOLS:
        write_line(fp)
        write_line(fp, "-- symbol window: %s --" % target)
        if target not in syms:
            write_line(fp, "symbol=ABSENT")
            continue

        start = syms[target]
        write_line(fp, "symbol_address=0x%x" % start)
        end = start + 0x500
        emitted = 0
        for addr, line in rows:
            if addr < start:
                continue
            if addr >= end:
                break
            write_line(fp, line)
            emitted += 1
        write_line(fp, "instruction_lines=%d" % emitted)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT

    tempdir = tempfile.mkdtemp(prefix="ls-ppc-gate-static.")
    try:
        with open(report, "w") as fp:
            rc, product = run(["/usr/bin/sw_vers", "-productVersion"])
            rc2, build = run(["/usr/bin/sw_vers", "-buildVersion"])
            write_line(fp, "== LaunchServices PPC gate static audit ==")
            write_line(fp, "product_version=%s" % product.strip())
            write_line(fp, "build_version=%s" % build.strip())
            write_line(fp, "kLSNoRosettaEnvironmentErr_decimal=-10665")
            write_line(fp, "kLSNoRosettaEnvironmentErr_u32=0x%08x" % ERROR32)

            for label, path in BINARIES:
                write_line(fp)
                write_line(fp, "============================================================")
                write_line(fp, "== %s ==" % label)
                write_line(fp, "path=%s" % path)

                if not os.path.isfile(path):
                    write_line(fp, "state=MISSING")
                    continue

                write_line(fp, "sha256=%s" % sha256(path))

                rc, out = run(["/usr/bin/file", path])
                write_line(fp, out.rstrip())

                if os.path.exists("/usr/bin/lipo"):
                    rc, out = run(["/usr/bin/lipo", "-info", path])
                    write_line(fp, out.rstrip())

                thin = os.path.join(tempdir, label + ".i386")
                ok, thin_out = thin_i386(path, thin)
                write_line(fp, "i386_thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    write_line(fp, thin_out.rstrip())
                    continue

                write_line(fp, "i386_sha256=%s" % sha256(thin))

                offsets = raw_occurrences(thin, ERROR_BYTES)
                write_line(fp, "raw_u32_-10665_occurrences=%d" % len(offsets))
                if offsets:
                    write_line(fp, "raw_u32_-10665_file_offsets=%s" %
                               ",".join("0x%x" % x for x in offsets[:64]))
                    if len(offsets) > 64:
                        write_line(fp, "raw_u32_-10665_offsets_omitted=%d" % (len(offsets) - 64))

                rc, strings_out = run(["/usr/bin/strings", "-a", thin])
                write_line(fp)
                write_line(fp, "== filtered strings ==")
                for line in strings_out.splitlines():
                    if STRING_RE.search(line):
                        write_line(fp, line)

                rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                write_line(fp)
                write_line(fp, "== filtered symbols/imports ==")
                for line in nm_out.splitlines():
                    if NM_RE.search(line):
                        write_line(fp, line)

                rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                write_line(fp)
                write_line(fp, "== disassembly contexts for -10665 ==")
                if rc == 0:
                    disassembly_error_context(fp, dis_out)
                else:
                    write_line(fp, "otool_disassembly_failed")
                    write_line(fp, dis_out.rstrip())

                if label == "LaunchServices" and rc == 0:
                    write_line(fp)
                    write_line(fp, "== LaunchServices target function windows ==")
                    symbol_windows(fp, nm_out, dis_out)

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No application was launched by this audit.")
            write_line(fp, "No registration database was modified by this audit.")
            write_line(fp, "No system file was modified by this audit.")

        print("Created: %s" % report)
        print("No application was launched and no system file was modified.")
        return 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
