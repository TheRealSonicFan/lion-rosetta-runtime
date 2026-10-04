#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./launchservices-unsupported-format-provenance.txt"
LS_BINARY = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"

TARGET_NAMES = [
    "__LSBundleDataGetUnsupportedFormatFlag",
    "__LSBundleCopyArchitecturesValidOnCurrentSystem",
    "__LSBundleCopyArchitecturesAvailable",
    "__LSGetCPUArchitecture",
    "__LSGetVersionForArchitecture",
]

INTEREST_RE = re.compile(
    r"(UnsupportedFormat|ArchitecturesValidOnCurrentSystem|ArchitecturesAvailable|"
    r"Register.*Bundle|Bundle.*Register|Registration|BundleData.*Flag)",
    re.I,
)

INSN_RE = re.compile(r"^\s*([0-9A-Fa-f]+)\s+(.*)$")
NM_RE = re.compile(r"^\s*([0-9A-Fa-f]+)\s+.*\s(\S+)$")
CALL_NUM_RE = re.compile(r"\bcalll\s+0x([0-9A-Fa-f]+)")
CALL_SYM_RE = re.compile(r"\bcalll\s+([^\s;]+)")


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


def thin_i386(src, dst):
    rc, out = run(["/usr/bin/lipo", src, "-verify_arch", "i386"])
    if rc != 0:
        rc, out = run(["/usr/bin/lipo", "-verify_arch", "i386", src])
    if rc != 0:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", "i386", "-output", dst])
    return rc == 0, out


def parse_symbols(text):
    symbols = []
    by_name = {}
    by_addr = {}
    for line in text.splitlines():
        m = NM_RE.match(line)
        if not m:
            continue
        try:
            addr = int(m.group(1), 16)
        except ValueError:
            continue
        name = m.group(2)
        symbols.append((addr, name))
        by_name[name] = addr
        if addr not in by_addr:
            by_addr[addr] = name
    symbols.sort()
    return symbols, by_name, by_addr


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


def nearest_symbol(symbols, addr):
    prev = None
    nxt = None
    for sym_addr, name in symbols:
        if sym_addr <= addr:
            prev = (sym_addr, name)
        else:
            nxt = (sym_addr, name)
            break
    return prev, nxt


def symbol_end(symbols, start, fallback):
    for addr, name in symbols:
        if addr > start:
            return min(addr, start + fallback)
    return start + fallback


def emit_symbol_window(fp, rows, symbols, by_name, name, fallback=0x500):
    fp.write("\n-- symbol window: %s --\n" % name)
    if name not in by_name:
        fp.write("symbol=ABSENT\n")
        return
    start = by_name[name]
    end = symbol_end(symbols, start, fallback)
    fp.write("symbol_address=0x%x\n" % start)
    fp.write("window_end=0x%x\n" % end)
    count = 0
    for addr, line in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        fp.write(line + "\n")
        count += 1
    fp.write("instruction_lines=%d\n" % count)


def line_calls_target(line, target_name, target_addr):
    if target_name in line and "calll" in line:
        return True
    m = CALL_NUM_RE.search(line)
    if m:
        try:
            return int(m.group(1), 16) == target_addr
        except ValueError:
            pass
    return False


def emit_callers(fp, rows, symbols, by_name, target_name):
    fp.write("\n== direct callers: %s ==\n" % target_name)
    if target_name not in by_name:
        fp.write("target=ABSENT\n")
        return

    target_addr = by_name[target_name]
    fp.write("target_address=0x%x\n" % target_addr)
    hits = []

    for idx, (addr, line) in enumerate(rows):
        if line_calls_target(line, target_name, target_addr):
            hits.append((idx, addr, line))

    fp.write("direct_caller_count=%d\n" % len(hits))

    for n, (idx, addr, line) in enumerate(hits):
        prev, nxt = nearest_symbol(symbols, addr)
        fp.write("\n-- caller %d --\n" % (n + 1))
        fp.write("call_instruction=%s\n" % line)
        if prev:
            fp.write("enclosing_symbol=%s\n" % prev[1])
            fp.write("enclosing_symbol_address=0x%x\n" % prev[0])
            fp.write("offset_from_symbol=0x%x\n" % (addr - prev[0]))
        else:
            fp.write("enclosing_symbol=UNKNOWN\n")
        if nxt:
            fp.write("next_symbol=%s\n" % nxt[1])

        start = max(0, idx - 24)
        end = min(len(rows), idx + 48)
        for j in range(start, end):
            fp.write(rows[j][1] + "\n")


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT

    if not os.path.isfile(LS_BINARY):
        print("error: missing LaunchServices binary: %s" % LS_BINARY, file=sys.stderr)
        return 66

    tempdir = tempfile.mkdtemp(prefix="ls-unsupported-provenance.")
    try:
        thin = os.path.join(tempdir, "LaunchServices.i386")
        ok, out = thin_i386(LS_BINARY, thin)
        if not ok:
            print("error: could not extract i386 LaunchServices", file=sys.stderr)
            print(out, file=sys.stderr)
            return 67

        rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
        if rc != 0:
            print("error: nm failed", file=sys.stderr)
            print(nm_out, file=sys.stderr)
            return 68

        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
        if rc != 0:
            print("error: otool disassembly failed", file=sys.stderr)
            print(dis_out, file=sys.stderr)
            return 69

        symbols, by_name, by_addr = parse_symbols(nm_out)
        rows = parse_instructions(dis_out)

        interesting = []
        for addr, name in symbols:
            if INTEREST_RE.search(name):
                interesting.append((addr, name))

        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])

            fp.write("== LaunchServices unsupported-format provenance audit ==\n")
            fp.write("product_version=%s\n" % product.strip())
            fp.write("build_version=%s\n" % build.strip())
            fp.write("launchservices_sha256=%s\n" % sha256(LS_BINARY))
            fp.write("i386_sha256=%s\n" % sha256(thin))
            fp.write("parsed_symbols=%d\n" % len(symbols))
            fp.write("parsed_instructions=%d\n" % len(rows))

            fp.write("\n== unsupported/registration-related symbols ==\n")
            fp.write("matching_symbol_count=%d\n" % len(interesting))
            for addr, name in interesting:
                fp.write("0x%x %s\n" % (addr, name))

            fp.write("\n== target symbol bodies ==\n")
            for name in TARGET_NAMES:
                emit_symbol_window(fp, rows, symbols, by_name, name, 0x700)

            fp.write("\n== target caller provenance ==\n")
            for name in TARGET_NAMES:
                emit_callers(fp, rows, symbols, by_name, name)

            fp.write("\n== all UnsupportedFormat symbol windows ==\n")
            for addr, name in interesting:
                if "unsupportedformat" in name.lower():
                    emit_symbol_window(fp, rows, symbols, by_name, name, 0x500)

            fp.write("\n== all UnsupportedFormat direct callers ==\n")
            for addr, name in interesting:
                if "unsupportedformat" in name.lower():
                    emit_callers(fp, rows, symbols, by_name, name)

            fp.write("\n== audit integrity ==\n")
            fp.write("No application was launched by this audit.\n")
            fp.write("No LaunchServices registration state was modified by this audit.\n")
            fp.write("No system file was modified by this audit.\n")

        print("Created: %s" % report)
        print("No application was launched and no system file was modified.")
        return 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
