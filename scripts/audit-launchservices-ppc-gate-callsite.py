#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./launchservices-ppc-gate-callsite.txt"
LS_BINARY = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"

TARGET_SYMBOLS = [
    "__LSBundleCopyArchitecturesAvailable",
    "__LSBundleCopyArchitecturesValidOnCurrentSystem",
    "__LSGetCPUArchitecture",
    "__LSGetVersionForArchitecture",
    "__LSAppMeetsRosettaRequirement",
    "__LSSetShouldFatApplicationLaunchPPC",
    "__LSShouldFatApplicationLaunchPPC",
    "__ZL15_LSAppCheckTypePK12LSBundleDataPKvl",
    "__ZL21_LSGetArchFlagsForURLPK7__CFURL",
]

ERROR_VALUE = "0xffffd657"
ERROR_OPERAND_RE = re.compile(r"(?:\$|\s|,)0xffffd657(?:\b|\()", re.I)
CALL_RE = re.compile(r"\bcalll\s+0x([0-9a-fA-F]+)")
INSN_RE = re.compile(r"^\s*([0-9A-Fa-f]+)\s+(.*)$")
NM_RE = re.compile(r"^\s*([0-9A-Fa-f]+)\s+.*\s(\S+)$")


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


def resolved_target(by_addr, addr):
    if addr in by_addr:
        return by_addr[addr]
    return None


def emit_instruction_context(fp, rows, idx, by_addr, before, after):
    start = max(0, idx - before)
    end = min(len(rows), idx + after + 1)
    for j in range(start, end):
        addr, line = rows[j]
        suffix = ""
        m = CALL_RE.search(line)
        if m:
            target = int(m.group(1), 16)
            name = resolved_target(by_addr, target)
            if name:
                suffix = "    ; resolved-target: %s" % name
        fp.write(line + suffix + "\n")


def emit_symbol_window(fp, rows, symbols, by_name, target, max_bytes=0x700):
    fp.write("\n-- symbol window: %s --\n" % target)
    if target not in by_name:
        fp.write("symbol=ABSENT\n")
        return

    start = by_name[target]
    fp.write("symbol_address=0x%x\n" % start)

    _, nxt = nearest_symbol(symbols, start)
    end = start + max_bytes
    if nxt is not None and nxt[0] > start:
        end = min(end, nxt[0])

    count = 0
    for addr, line in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        fp.write(line + "\n")
        count += 1
    fp.write("instruction_lines=%d\n" % count)


def emit_callers(fp, rows, symbols, target_addr, target_name):
    fp.write("\n-- direct callers of %s (0x%x) --\n" % (target_name, target_addr))
    found = 0
    for idx, (addr, line) in enumerate(rows):
        m = CALL_RE.search(line)
        if not m:
            continue
        try:
            called = int(m.group(1), 16)
        except ValueError:
            continue
        if called != target_addr:
            continue

        found += 1
        prev, nxt = nearest_symbol(symbols, addr)
        if prev:
            fp.write("caller_instruction=0x%x enclosing_symbol=%s+0x%x\n" %
                     (addr, prev[1], addr - prev[0]))
        else:
            fp.write("caller_instruction=0x%x enclosing_symbol=UNKNOWN\n" % addr)

        start = max(0, idx - 10)
        end = min(len(rows), idx + 12)
        for j in range(start, end):
            fp.write(rows[j][1] + "\n")
        fp.write("\n")

    fp.write("direct_caller_count=%d\n" % found)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT

    if not os.path.isfile(LS_BINARY):
        print("error: missing LaunchServices binary: %s" % LS_BINARY, file=sys.stderr)
        return 66

    tempdir = tempfile.mkdtemp(prefix="ls-ppc-callsite.")
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

        with open(report, "w") as fp:
            _, product = run(["/usr/bin/sw_vers", "-productVersion"])
            _, build = run(["/usr/bin/sw_vers", "-buildVersion"])

            fp.write("== LaunchServices PPC gate callsite audit ==\n")
            fp.write("product_version=%s\n" % product.strip())
            fp.write("build_version=%s\n" % build.strip())
            fp.write("launchservices_sha256=%s\n" % sha256(LS_BINARY))
            fp.write("i386_sha256=%s\n" % sha256(thin))
            fp.write("error_value=%s\n" % ERROR_VALUE)
            fp.write("parsed_symbols=%d\n" % len(symbols))
            fp.write("parsed_instructions=%d\n" % len(rows))

            fp.write("\n== exact -10665 operand sites ==\n")
            error_indices = []
            for idx, (addr, line) in enumerate(rows):
                body = line.split("\t", 1)[1] if "\t" in line else line
                if ERROR_OPERAND_RE.search(body):
                    error_indices.append(idx)

            fp.write("exact_error_operand_sites=%d\n" % len(error_indices))

            enclosing = []
            for n, idx in enumerate(error_indices):
                addr, line = rows[idx]
                prev, nxt = nearest_symbol(symbols, addr)
                fp.write("\n-- -10665 site %d --\n" % (n + 1))
                fp.write("instruction=%s\n" % line)
                if prev:
                    fp.write("enclosing_symbol=%s\n" % prev[1])
                    fp.write("enclosing_symbol_address=0x%x\n" % prev[0])
                    fp.write("offset_from_symbol=0x%x\n" % (addr - prev[0]))
                    enclosing.append(prev)
                else:
                    fp.write("enclosing_symbol=UNKNOWN\n")
                if nxt:
                    fp.write("next_symbol=%s\n" % nxt[1])
                    fp.write("next_symbol_address=0x%x\n" % nxt[0])

                fp.write("== surrounding instructions ==\n")
                emit_instruction_context(fp, rows, idx, by_addr, 80, 140)

            fp.write("\n== corrected target symbol windows ==\n")
            for target in TARGET_SYMBOLS:
                emit_symbol_window(fp, rows, symbols, by_name, target)

            seen = set()
            fp.write("\n== direct callers of -10665 enclosing functions ==\n")
            for item in enclosing:
                if item in seen:
                    continue
                seen.add(item)
                emit_callers(fp, rows, symbols, item[0], item[1])

            fp.write("\n== neighborhood symbols around each -10665 site ==\n")
            for idx in error_indices:
                addr, _ = rows[idx]
                low = max(0, addr - 0x1800)
                high = addr + 0x1800
                fp.write("\nsite=0x%x range=0x%x-0x%x\n" % (addr, low, high))
                for sym_addr, name in symbols:
                    if sym_addr < low:
                        continue
                    if sym_addr > high:
                        break
                    fp.write("0x%x %s\n" % (sym_addr, name))

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
