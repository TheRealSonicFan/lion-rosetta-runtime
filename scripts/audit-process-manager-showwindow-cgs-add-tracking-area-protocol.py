#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-showwindow-cgs-add-tracking-area-protocol.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

TARGET_FAMILIES = [
    "CGSAddTrackingArea",
    "CGSRemoveTrackingArea",
    "TrackingArea",
    "TrackingRegion",
]
REQUIRED_FAMILY = "CGSAddTrackingArea"

LIVE_LEGACY_REQUEST_ID = 0x00007388
LIVE_LEGACY_REPLY_ID = 0x000073ec

FOCUS_RE = re.compile(
    r"(CGSAddTrackingArea|CGSRemoveTrackingArea|TrackingArea|TrackingRegion|"
    r"mach_msg|mig_get_reply_port|mig_put_reply_port|mig_dealloc_reply_port|"
    r"MIG_|NDR|WindowServer|windowserver|tracking|region|window)",
    re.I,
)
STRING_RE = re.compile(
    r"(CGSAddTrackingArea|CGSRemoveTrackingArea|TrackingArea|TrackingRegion|"
    r"WindowServer|windowserver|tracking|region|CGS)",
    re.I,
)

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

def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")

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

def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True, out
    rc2, out2 = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    if rc2 == 0:
        return True, out2
    if out2.strip():
        return False, out2
    return False, out

def thin_arch(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out

def parse_symbols(text):
    ordered = []
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
    ordered.sort()
    return ordered

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

def symbol_window_rows(rows, ordered_text, start, max_bytes=0x8000):
    end = start + max_bytes
    nxt = next_symbol_address(ordered_text, start)
    if nxt is not None:
        end = min(end, nxt)
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]

def family_symbols(ordered, family):
    hits = []
    for addr, name, line, is_text in ordered:
        if is_text and family in name:
            hits.append((addr, name))
    return sorted(set(hits))

def emit_symbol_window(fp, rows, ordered_text, name, start):
    selected = symbol_window_rows(rows, ordered_text, start)
    write_line(fp)
    write_line(fp, "== target: %s ==" % name)
    write_line(fp, "symbol_address=0x%x" % start)
    write_line(fp, "instruction_lines=%d" % len(selected))

    write_line(fp, "-- full symbol window --")
    for addr, line in selected:
        write_line(fp, line)

    write_line(fp, "-- direct calls/branches --")
    calls = []
    for addr, line in selected:
        lower = line.lower()
        if ("\tcall" in lower or "\tbl\t" in lower or
                "\tb\t" in lower or "\tjmp" in lower):
            calls.append(line)
    if calls:
        for line in calls:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    write_line(fp, "-- MIG transport lines --")
    mig = []
    for addr, line in selected:
        lower = line.lower()
        if ("mach_msg" in lower or "mig_get_reply_port" in lower or
                "mig_put_reply_port" in lower or
                "mig_dealloc_reply_port" in lower or "ndr" in lower):
            mig.append(line)
    if mig:
        for line in mig:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

    write_line(fp, "-- immediate-bearing lines --")
    immediates = [line for addr, line in selected if "0x" in line]
    if immediates:
        for line in immediates:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")

def emit_references(fp, dis_lines, name, address):
    write_line(fp)
    write_line(fp, "-- references to %s @ 0x%x --" % (name, address))
    refs = []
    forms = ["0x%x" % address, "%08x" % address, "%016x" % address]
    for line in dis_lines:
        if name in line:
            refs.append(line)
            continue
        lower = line.lower()
        if ("call" in lower or "\tbl\t" in lower or
                "\tb\t" in lower or "jmp" in lower):
            for form in forms:
                if form in line:
                    refs.append(line)
                    break
    write_line(fp, "reference_lines=%d" % len(refs))
    for line in refs[:1200]:
        write_line(fp, line)
    if len(refs) > 1200:
        write_line(fp, "additional_reference_lines_omitted=%d" % (len(refs) - 1200))

def emit_live_id_context(fp, rows):
    write_line(fp)
    write_line(fp, "== live legacy ID anchors ==")
    write_line(fp, "legacy_request_id=0x%08x" % LIVE_LEGACY_REQUEST_ID)
    write_line(fp, "legacy_reply_id=0x%08x" % LIVE_LEGACY_REPLY_ID)

    request_forms = [
        "0x%x" % LIVE_LEGACY_REQUEST_ID,
        "0x%08x" % LIVE_LEGACY_REQUEST_ID,
    ]
    reply_forms = [
        "0x%x" % LIVE_LEGACY_REPLY_ID,
        "0x%08x" % LIVE_LEGACY_REPLY_ID,
    ]

    hit_indexes = []
    for i, item in enumerate(rows):
        line = item[1].lower()
        if any(form.lower() in line for form in request_forms + reply_forms):
            hit_indexes.append(i)

    write_line(fp, "anchor_instruction_hits=%d" % len(hit_indexes))
    emitted = set()
    for i in hit_indexes:
        start = max(0, i - 12)
        end = min(len(rows), i + 13)
        key = (start, end)
        if key in emitted:
            continue
        emitted.add(key)
        write_line(fp)
        write_line(fp, "-- anchor context rows %d..%d --" % (start, end - 1))
        for j in range(start, end):
            write_line(fp, rows[j][1])

def cache_provenance(fp):
    write_line(fp)
    write_line(fp, "== Rosetta shared-cache provenance ==")
    if os.path.isfile(ROSETTA_CACHE):
        write_line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
    else:
        write_line(fp, "rosetta_cache=MISSING")
    if not os.path.isfile(ROSETTA_MAP):
        write_line(fp, "rosetta_cache_map=MISSING")
        return
    write_line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
    try:
        data = open(ROSETTA_MAP, "r").read()
    except IOError as e:
        write_line(fp, "rosetta_cache_map_read_error=%s" % e)
        return
    matches = [line for line in data.splitlines() if COREGRAPHICS in line]
    write_line(fp, "cache_map_path=%s" % COREGRAPHICS)
    write_line(fp, "cache_map_contains=%s" % ("YES" if matches else "NO"))
    for line in matches[:8]:
        write_line(fp, line)

def emit_focused_cstrings(fp, thin):
    write_line(fp)
    write_line(fp, "-- addressed focused cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "otool_cstring_dump_failed")
        write_line(fp, out.rstrip())
        return
    hits = [line for line in out.splitlines() if STRING_RE.search(line)]
    for line in hits[:1200]:
        write_line(fp, line)
    if len(hits) > 1200:
        write_line(fp, "additional_cstring_hits_omitted=%d" % (len(hits) - 1200))

def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-showwindow-cgs-tracking.")
    issues = []

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8":
            required_arch = "ppc7400"
        elif product == "10.7.5":
            required_arch = "i386"
        else:
            required_arch = None
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager ShowWindow CGSAddTrackingArea protocol differential audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (required_arch if required_arch else "UNSUPPORTED"))
            write_line(fp, "live_legacy_request_id=0x%08x" % LIVE_LEGACY_REQUEST_ID)
            write_line(fp, "live_legacy_reply_id=0x%08x" % LIVE_LEGACY_REPLY_ID)

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())
            cache_provenance(fp)

            write_line(fp)
            write_line(fp, "== CoreGraphics ==")
            write_line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                write_line(fp, "state=MISSING")
                issues.append("CoreGraphics binary missing")
            elif required_arch is not None:
                write_line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                rc, out = run(["/usr/bin/file", COREGRAPHICS])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREGRAPHICS])
                write_line(fp, out.rstrip())

                thin = os.path.join(tempdir, "CoreGraphics.%s" % required_arch)
                ok, out = thin_arch(COREGRAPHICS, required_arch, thin)
                write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    write_line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing: %s" % required_arch)
                else:
                    write_line(fp, "slice_sha256=%s" % sha256(thin))

                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        write_line(fp, "-- nm failed --")
                        write_line(fp, nm_out.rstrip())
                        issues.append("nm failed")
                    else:
                        ordered = parse_symbols(nm_out)
                        ordered_text = text_symbols(ordered)

                        write_line(fp)
                        write_line(fp, "-- focused symbols/imports --")
                        nm_hits = [line for line in nm_out.splitlines() if FOCUS_RE.search(line)]
                        for line in nm_hits[:3200]:
                            write_line(fp, line)
                        if len(nm_hits) > 3200:
                            write_line(fp, "additional_nm_hits_omitted=%d" % (len(nm_hits) - 3200))

                        rc, strings_out = run(["/usr/bin/strings", "-a", thin])
                        write_line(fp)
                        write_line(fp, "-- focused strings --")
                        if rc == 0:
                            string_hits = [line for line in strings_out.splitlines() if STRING_RE.search(line)]
                            for line in string_hits[:1600]:
                                write_line(fp, line)
                            if len(string_hits) > 1600:
                                write_line(fp, "additional_string_hits_omitted=%d" % (len(string_hits) - 1600))
                        else:
                            write_line(fp, "strings_failed")

                        emit_focused_cstrings(fp, thin)

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                        if rc != 0:
                            write_line(fp, "-- disassembly failed --")
                            write_line(fp, dis_out.rstrip())
                            issues.append("otool disassembly failed")
                        else:
                            rows = parse_instructions(dis_out)
                            dis_lines = dis_out.splitlines()
                            write_line(fp, "parsed_text_symbols=%d" % len(ordered_text))
                            write_line(fp, "parsed_instruction_lines=%d" % len(rows))

                            write_line(fp)
                            write_line(fp, "== target family inventory ==")
                            selected = []
                            add_hits = []
                            for family in TARGET_FAMILIES:
                                hits = family_symbols(ordered, family)
                                if family == REQUIRED_FAMILY:
                                    add_hits = hits
                                if hits:
                                    write_line(fp, "%s count=%d symbols=%s" %
                                               (family, len(hits),
                                                ",".join("%s@0x%x" % (name, addr)
                                                         for addr, name in hits)))
                                    selected.extend(hits)
                                else:
                                    write_line(fp, "%s count=0" % family)

                            if not add_hits:
                                issues.append("CGSAddTrackingArea target family missing")

                            emit_live_id_context(fp, rows)

                            emitted = set()
                            for addr, name in sorted(selected):
                                key = (addr, name)
                                if key in emitted:
                                    continue
                                emitted.add(key)
                                emit_symbol_window(fp, rows, ordered_text, name, addr)
                                emit_references(fp, dis_lines, name, addr)

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
            write_line(fp, "No ShowWindow, CGS, CPS, bootstrap, Mach, or WindowServer request was issued by this audit.")
            write_line(fp, "No CoreGraphics, WindowServer, Rosetta, dyld, launchd, or XNU state was modified by this audit.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
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
