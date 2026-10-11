#!/usr/bin/python
from __future__ import print_function

import binascii
import os
import plistlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-fontserver-first-rpc-protocol-audit.txt"
ANALYZER_VERSION = "1"

FONTREGISTRY = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ATS.framework/Versions/A/Resources/libFontRegistry.dylib"
CORETEXT = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreText.framework/Versions/A/CoreText"
ATS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ATS.framework/Versions/A/ATS"

CLIENT_IMAGES = [
    ("FontRegistry", FONTREGISTRY),
    ("CoreText", CORETEXT),
    ("ATS", ATS),
]

LAUNCH_DIRS = [
    "/System/Library/LaunchAgents",
    "/System/Library/LaunchDaemons",
    "/Library/LaunchAgents",
    "/Library/LaunchDaemons",
]

REQUEST_IDS = [0x32c8, 0x32cb, 0x32d9, 0x32db]
REPLY_IDS = [x + 100 for x in REQUEST_IDS]
ALL_IDS = REQUEST_IDS + REPLY_IDS

FOCUS_RE = re.compile(
    r"(fontserver|font server|fontregistry|fontmanager|copyfont|"
    r"matchingrequest|mach_msg|mig_|ndr|bootstrap|serverport|fontd)",
    re.I,
)

STRING_RE = re.compile(
    r"(fontserver|font server|fontregistry|fontmanager|copyfont|"
    r"matchingrequest|fontd)",
    re.I,
)


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def line(fp, s=""):
    fp.write(s)
    fp.write("\n")


def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]


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
    rows = []
    for raw in text.splitlines():
        parts = raw.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        is_text = "(__TEXT,__text)" in raw
        if is_text:
            rows.append((addr, name))
    rows.sort()
    return rows


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


def arch_aliases(arch):
    if arch == "ppc7400":
        return ["ppc7400", "ppc"]
    return [arch]


def verify_arch(path, arch):
    last = ""
    for a in arch_aliases(arch):
        for cmd in [
            ["/usr/bin/lipo", "-verify_arch", a, path],
            ["/usr/bin/lipo", path, "-verify_arch", a],
        ]:
            rc, out = run(cmd)
            last = out
            if rc == 0:
                return True, a, out
    return False, None, last


def thin_arch(path, arch, dst):
    ok, actual, out = verify_arch(path, arch)
    if not ok:
        return False, None, out
    rc, out = run(["/usr/bin/lipo", path, "-thin", actual, "-output", dst])
    return rc == 0, actual, out


def enclosing_symbol(symbols, addr):
    found = None
    for saddr, name in symbols:
        if saddr > addr:
            break
        found = (saddr, name)
    return found


def next_symbol(symbols, addr):
    for saddr, name in symbols:
        if saddr > addr:
            return saddr
    return None


def id_forms(value):
    return [
        "0x%x" % value,
        "0x%08x" % value,
        "%d" % value,
    ]


def line_mentions_id(raw, value):
    low = raw.lower()
    for form in id_forms(value):
        f = form.lower()
        if f.startswith("0x"):
            if f in low:
                return True
        else:
            if re.search(r"(^|[^0-9])%s([^0-9]|$)" % re.escape(f), raw):
                return True
    return False


def hex_context(data, off, radius=32):
    lo = max(0, off - radius)
    hi = min(len(data), off + 4 + radius)
    return lo, hi, binascii.hexlify(data[lo:hi]).decode("ascii")


def raw_id_hits(path):
    data = open(path, "rb").read()
    hits = {}
    for value in ALL_IDS:
        patterns = [
            ("be", struct.pack(">I", value)),
            ("le", struct.pack("<I", value)),
        ]
        vhits = []
        for endian, pat in patterns:
            start = 0
            while True:
                pos = data.find(pat, start)
                if pos < 0:
                    break
                vhits.append((pos, endian))
                start = pos + 1
                if len(vhits) >= 128:
                    break
        hits[value] = vhits
    return data, hits


def emit_raw_hits(fp, thin):
    line(fp)
    line(fp, "-- raw exact RPC ID occurrences --")
    try:
        data, hits = raw_id_hits(thin)
    except IOError as e:
        line(fp, "raw_read_error=%s" % e)
        return 0

    total = 0
    for value in ALL_IDS:
        vhits = hits.get(value, [])
        total += len(vhits)
        line(fp, "id=0x%08x decimal=%d raw_hits=%d" %
             (value, value, len(vhits)))
        for off, endian in vhits[:24]:
            lo, hi, blob = hex_context(data, off)
            line(fp,
                 "  fileOffset=0x%x endian=%s contextOffset=0x%x contextEnd=0x%x hex=%s" %
                 (off, endian, lo, hi, blob))
        if len(vhits) > 24:
            line(fp, "  additional_raw_hits_omitted=%d" % (len(vhits) - 24))
    line(fp, "raw_target_hit_total=%d" % total)
    return total


def emit_focused_strings(fp, thin):
    rc, out = run(["/usr/bin/strings", "-a", thin])
    line(fp)
    line(fp, "-- focused strings --")
    if rc != 0:
        line(fp, "strings_failed")
        return
    hits = [x for x in out.splitlines() if STRING_RE.search(x)]
    for x in hits[:800]:
        line(fp, x)
    if len(hits) > 800:
        line(fp, "additional_string_hits_omitted=%d" % (len(hits) - 800))


def emit_function_window(fp, rows, symbols, start, name):
    end = start + 0x6000
    nxt = next_symbol(symbols, start)
    if nxt is not None:
        end = min(end, nxt)
    line(fp)
    line(fp, "-- function window: %s @ 0x%x --" % (name, start))
    count = 0
    for addr, raw in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        line(fp, raw)
        count += 1
    line(fp, "instruction_lines=%d" % count)


def analyze_slice(fp, label, path, arch, tempdir):
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", label)
    thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
    ok, actual, out = thin_arch(path, arch, thin)

    line(fp)
    line(fp, "== %s slice: %s ==" % (label, arch))
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    if not ok:
        line(fp, out.rstrip())
        return {
            "label": label, "arch": arch, "present": False,
            "analyzed": False, "target_hits": 0, "raw_hits": 0,
        }

    line(fp, "thin_arch=%s" % actual)
    line(fp, "slice_sha256=%s" % sha256(thin))

    rc, deps = run(["/usr/bin/otool", "-L", thin])
    line(fp, "-- dependencies --")
    line(fp, deps.rstrip())

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    line(fp)
    line(fp, "-- focused symbols/imports --")
    if rc == 0:
        focused = [x for x in nm_out.splitlines() if FOCUS_RE.search(x)]
        for x in focused[:1600]:
            line(fp, x)
        if len(focused) > 1600:
            line(fp, "additional_symbol_hits_omitted=%d" % (len(focused) - 1600))
        symbols = parse_symbols(nm_out)
    else:
        line(fp, "nm_failed")
        line(fp, nm_out.rstrip())
        symbols = []

    emit_focused_strings(fp, thin)
    raw_hits = emit_raw_hits(fp, thin)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        line(fp)
        line(fp, "-- disassembly failed --")
        line(fp, dis_out.rstrip())
        return {
            "label": label, "arch": arch, "present": True,
            "analyzed": False, "target_hits": 0, "raw_hits": raw_hits,
        }

    rows = parse_instructions(dis_out)
    line(fp)
    line(fp, "-- exact RPC ID instruction hits --")
    hits = []
    emitted_functions = set()
    for addr, raw in rows:
        matched = [value for value in ALL_IDS if line_mentions_id(raw, value)]
        if not matched:
            continue
        hits.append((addr, raw, matched))
        line(fp, "address=0x%x ids=%s line=%s" %
             (addr,
              ",".join("0x%08x" % x for x in matched),
              raw))

    line(fp, "instruction_target_hit_count=%d" % len(hits))

    line(fp)
    line(fp, "-- focused disassembly lines --")
    focus_lines = [raw for addr, raw in rows if FOCUS_RE.search(raw)]
    for raw in focus_lines[:1800]:
        line(fp, raw)
    if len(focus_lines) > 1800:
        line(fp, "additional_focused_disassembly_omitted=%d" %
             (len(focus_lines) - 1800))

    for addr, raw, matched in hits:
        owner = enclosing_symbol(symbols, addr)
        if owner is None:
            line(fp)
            line(fp, "-- local instruction context around 0x%x --" % addr)
            positions = [i for i, row in enumerate(rows) if row[0] == addr]
            if positions:
                pos = positions[0]
                for xaddr, xraw in rows[max(0, pos - 40):min(len(rows), pos + 80)]:
                    line(fp, xraw)
            continue

        start, name = owner
        key = (start, name)
        if key in emitted_functions:
            continue
        emitted_functions.add(key)
        emit_function_window(fp, rows, symbols, start, name)

    return {
        "label": label, "arch": arch, "present": True,
        "analyzed": True, "target_hits": len(hits),
        "raw_hits": raw_hits,
    }


def discover_fontserver_jobs(fp):
    line(fp)
    line(fp, "== Static launchd FontServer/fontd discovery ==")
    matches = []
    programs = []

    for root in LAUNCH_DIRS:
        if not os.path.isdir(root):
            continue
        try:
            names = sorted(os.listdir(root))
        except OSError:
            continue
        for name in names:
            if not name.endswith(".plist"):
                continue
            path = os.path.join(root, name)
            try:
                data = open(path, "rb").read()
            except IOError:
                continue
            low = data.lower()
            if b"fontserver" not in low and b"fontd" not in low:
                continue
            matches.append(path)
            line(fp, "plist=%s sha256=%s" % (path, sha256(path)))
            try:
                obj = plistlib.readPlist(path)
            except Exception as e:
                line(fp, "plist_parse_error=%s" % e)
                continue
            for key in ["Label", "Program", "ProgramArguments", "MachServices"]:
                if key in obj:
                    line(fp, "%s=%r" % (key, obj[key]))
            program = obj.get("Program")
            args = obj.get("ProgramArguments")
            if not program and isinstance(args, list) and args:
                program = args[0]
            if isinstance(program, basestring) if sys.version_info[0] < 3 else isinstance(program, str):
                if program not in programs:
                    programs.append(program)

    if not matches:
        line(fp, "matching_plists=NONE")
    line(fp, "matching_plist_count=%d" % len(matches))
    for program in programs:
        line(fp, "discovered_program=%s exists=%s" %
             (program, "YES" if os.path.isfile(program) else "NO"))
    return programs


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-fontserver-rpc-audit.")
    issues = []
    results = []

    try:
        _, product = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product.strip()
        build = build.strip()

        if product == "10.6.8":
            required_arch = "ppc7400"
            optional_arches = ["i386", "x86_64"]
        elif product == "10.7.5":
            required_arch = "i386"
            optional_arches = ["x86_64"]
        else:
            required_arch = None
            optional_arches = []
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            line(fp, "== Process Manager FontServer first-RPC protocol differential audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)

            line(fp)
            line(fp, "== Live evidence entering this audit ==")
            line(fp, "snow_first_request_id=0x000032c8")
            line(fp, "snow_first_send=0x00000018")
            line(fp, "snow_first_recv=0x0000003c")
            line(fp, "snow_first_reply_id=0x0000332c")
            line(fp, "snow_first_reply_size=0x00000034")
            line(fp, "snow_first_reply_complex=YES")
            line(fp, "lion_first_request_id=0x000032c8")
            line(fp, "lion_first_send=0x00000018")
            line(fp, "lion_first_recv=0x0000003c")
            line(fp, "lion_first_reply_id=0x0000332c")
            line(fp, "lion_first_reply_size=0x00000024")
            line(fp, "lion_first_reply_complex=NO")
            line(fp, "lion_first_reply_raw_word20_bytes=65fdffff")
            line(fp, "lion_later_0x32d9_reply_raw_word20_bytes=d0feffff")
            line(fp, "lion_CoreText_reports_0x32d9_error=FFFFFED0")
            line(fp, "note=headerSizeObserved is not authoritative; mach_msg send-size argument is authoritative")

            service_programs = discover_fontserver_jobs(fp)

            images = list(CLIENT_IMAGES)
            for idx, path in enumerate(service_programs):
                if os.path.isfile(path):
                    images.append(("FontServiceProgram%d" % (idx + 1), path))

            for label, path in images:
                line(fp)
                line(fp, "============================================================")
                line(fp, "== Image: %s ==" % label)
                line(fp, "path=%s" % path)
                if not os.path.isfile(path):
                    line(fp, "state=MISSING")
                    if label == "FontRegistry":
                        issues.append("FontRegistry binary missing")
                    continue

                line(fp, "sha256=%s" % sha256(path))
                rc, out = run(["/usr/bin/file", path])
                line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", path])
                line(fp, out.rstrip())

                arches = []
                if required_arch is not None:
                    arches.append(required_arch)
                for arch in optional_arches:
                    if arch not in arches:
                        arches.append(arch)

                for arch in arches:
                    result = analyze_slice(fp, label, path, arch, tempdir)
                    results.append(result)

            line(fp)
            line(fp, "== Audit validation ==")
            required_client = [
                x for x in results
                if x["label"] in ("FontRegistry", "CoreText", "ATS") and
                   x["arch"] == required_arch and x["present"] and x["analyzed"]
            ]

            if required_arch is not None and not required_client:
                issues.append("no required %s client slice was analyzable" % required_arch)

            target_total = sum(
                x["target_hits"] + x["raw_hits"] for x in required_client
            )
            line(fp, "required_client_analyzed_count=%d" % len(required_client))
            line(fp, "required_client_target_evidence_total=%d" % target_total)
            if required_client and target_total == 0:
                issues.append("required client slices contain no evidence for captured RPC IDs")

            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PPC or native test application was launched by this audit.")
            line(fp, "No bootstrap lookup or FontServer Mach request was issued by this audit.")
            line(fp, "No launchd job was started, stopped, restarted, or signaled.")
            line(fp, "No framework, FontServer/fontd binary, Rosetta component, cache, or XNU file was modified.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        print("No application was launched and no system state was modified.")
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
