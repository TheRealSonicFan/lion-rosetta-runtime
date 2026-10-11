#!/usr/bin/python
from __future__ import print_function

import binascii
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./process-manager-fontserver-rendezvous-protocol-v2.txt"
ANALYZER_VERSION = "2"

FONTREGISTRY = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ATS.framework/Versions/A/Resources/libFontRegistry.dylib"
ATSSERVER = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ATS.framework/Versions/A/Resources/libATSServer.dylib"

CLIENT_SYMBOLS = [
    "_XTSendRendezvous",
    "_XTSendRendezvous2",
    "__ZNK22TGlobalFontRegistryImp20RendezvousWithServerEv",
    "__ZNK22TGlobalFontRegistryImp13GetServerPortEv",
]

SERVER_SYMBOL_RE = re.compile(
    r"(rendezvous|fontserver|font_server|font.*server|server.*font|"
    r"demux|mach_msg_server|handlemessage|dispatch|xtserver)",
    re.I,
)

FOCUS_RE = re.compile(
    r"(rendezvous|fontserver|font server|fontd|fontregistry|"
    r"mach_msg|mig_|ndr|bootstrap|demux|dispatch)",
    re.I,
)

STRING_RE = re.compile(
    r"(rendezvous|fontserver|font server|protocol version|fontd|"
    r"fontobjectsserver|could not rendezvous)",
    re.I,
)

PROTO_MIN = 0x3200
PROTO_MAX = 0x3400

ERROR_VALUES = [
    ("lion_first_raw_status", 0xfffffd65),
    ("mig_bad_arguments", 0xfffffed0),
]


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
        if "(__TEXT,__text)" not in raw:
            continue
        rows.append((addr, parts[-1]))
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


def next_symbol(symbols, start):
    for addr, name in symbols:
        if addr > start:
            return addr
    return None


def enclosing_symbol(symbols, addr):
    found = None
    for saddr, name in symbols:
        if saddr > addr:
            break
        found = (saddr, name)
    return found


def arch_aliases(arch):
    if arch == "ppc7400":
        return ["ppc7400", "ppc"]
    return [arch]


def verify_arch(path, arch):
    last = ""
    for actual in arch_aliases(arch):
        for cmd in [
            ["/usr/bin/lipo", "-verify_arch", actual, path],
            ["/usr/bin/lipo", path, "-verify_arch", actual],
        ]:
            rc, out = run(cmd)
            last = out
            if rc == 0:
                return True, actual, out
    return False, None, last


def thin_arch(path, arch, dst):
    ok, actual, out = verify_arch(path, arch)
    if not ok:
        return False, None, out
    rc, out = run(["/usr/bin/lipo", path, "-thin", actual, "-output", dst])
    return rc == 0, actual, out


def symbol_addresses(symbols, wanted):
    return [(addr, name) for addr, name in symbols if name == wanted]


def extract_hex_values(raw):
    vals = []
    for token in re.findall(r"0x[0-9a-fA-F]+", raw):
        try:
            vals.append(int(token, 16))
        except ValueError:
            pass
    return vals


def protocol_immediate_values(raw):
    lower = raw.lower()

    x86_immediate = "$0x" in lower
    ppc_immediate = re.search(
        r"\b(li|lis|cmpwi|cmplwi|addi|addis|ori|oris)\b[^\n]*0x",
        lower,
    ) is not None

    if not x86_immediate and not ppc_immediate:
        return []

    return [v for v in extract_hex_values(raw)
            if PROTO_MIN <= v <= PROTO_MAX]


def emit_function_window(fp, rows, symbols, start, name):
    end = start + 0x8000
    nxt = next_symbol(symbols, start)
    if nxt is not None:
        end = min(end, nxt)

    selected = []
    for addr, raw in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        selected.append((addr, raw))

    line(fp)
    line(fp, "-- exact function window: %s @ 0x%x --" % (name, start))
    for addr, raw in selected:
        line(fp, raw)
    line(fp, "instruction_lines=%d" % len(selected))

    line(fp, "-- protocol-range immediates in %s --" % name)
    proto_hits = 0
    for addr, raw in selected:
        values = protocol_immediate_values(raw)
        if values:
            proto_hits += 1
            line(fp, "address=0x%x values=%s line=%s" %
                 (addr,
                  ",".join("0x%08x" % v for v in values),
                  raw))
    line(fp, "protocol_immediate_lines=%d" % proto_hits)

    line(fp, "-- error/status immediates in %s --" % name)
    err_hits = 0
    low_selected = [(addr, raw.lower()) for addr, raw in selected]
    for label, value in ERROR_VALUES:
        forms = [
            "0x%08x" % value,
            "0x%x" % value,
            "0x%04x" % (value & 0xffff),
        ]
        for (addr, raw), (_, low) in zip(selected, low_selected):
            if any(form.lower() in low for form in forms):
                err_hits += 1
                line(fp, "label=%s value=0x%08x address=0x%x line=%s" %
                     (label, value, addr, raw))
    line(fp, "status_immediate_lines=%d" % err_hits)

    return proto_hits


def raw_value_hits(fp, thin, label, value):
    try:
        data = open(thin, "rb").read()
    except IOError as e:
        line(fp, "%s_raw_read_error=%s" % (label, e))
        return 0

    hits = []
    for endian, pat in [
        ("be", struct.pack(">I", value)),
        ("le", struct.pack("<I", value)),
    ]:
        start = 0
        while True:
            pos = data.find(pat, start)
            if pos < 0:
                break
            lo = max(0, pos - 32)
            hi = min(len(data), pos + 36)
            blob = binascii.hexlify(data[lo:hi])
            if not isinstance(blob, str):
                blob = blob.decode("ascii")
            hits.append((pos, endian, lo, hi, blob))
            start = pos + 1
            if len(hits) >= 128:
                break

    line(fp, "%s value=0x%08x raw_hits=%d" % (label, value, len(hits)))
    for pos, endian, lo, hi, blob in hits[:32]:
        line(fp,
             "  fileOffset=0x%x endian=%s contextOffset=0x%x contextEnd=0x%x hex=%s" %
             (pos, endian, lo, hi, blob))
    if len(hits) > 32:
        line(fp, "  additional_raw_hits_omitted=%d" % (len(hits) - 32))
    return len(hits)


def emit_focused_strings(fp, thin):
    rc, out = run(["/usr/bin/strings", "-a", thin])
    line(fp)
    line(fp, "-- focused strings --")
    if rc != 0:
        line(fp, "strings_failed")
        return 0
    hits = [x for x in out.splitlines() if STRING_RE.search(x)]
    for x in hits[:1000]:
        line(fp, x)
    if len(hits) > 1000:
        line(fp, "additional_string_hits_omitted=%d" % (len(hits) - 1000))
    line(fp, "focused_string_count=%d" % len(hits))
    return len(hits)


def emit_protocol_range_instruction_inventory(fp, rows, symbols):
    line(fp)
    line(fp, "-- whole-image protocol-range immediate inventory --")
    hits = []
    owners = {}
    for addr, raw in rows:
        values = sorted(set(protocol_immediate_values(raw)))
        if not values:
            continue
        owner = enclosing_symbol(symbols, addr)
        owner_text = "NONE"
        if owner is not None:
            owner_text = "%s@0x%x" % (owner[1], owner[0])
            owners[owner] = True
        hits.append((addr, values, owner_text, raw))
        line(fp, "address=0x%x values=%s owner=%s line=%s" %
             (addr,
              ",".join("0x%08x" % v for v in values),
              owner_text,
              raw))
    line(fp, "protocol_range_instruction_hit_count=%d" % len(hits))
    return hits, owners


def analyze_image(fp, label, path, arches, tempdir):
    results = []

    line(fp)
    line(fp, "============================================================")
    line(fp, "== Image: %s ==" % label)
    line(fp, "path=%s" % path)

    if not os.path.isfile(path):
        line(fp, "state=MISSING")
        return results

    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    line(fp, out.rstrip())

    for arch in arches:
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", label)
        thin = os.path.join(tempdir, "%s.%s" % (safe, arch))
        ok, actual, out = thin_arch(path, arch, thin)

        line(fp)
        line(fp, "== %s slice: %s ==" % (label, arch))
        line(fp, "thin=%s" % ("YES" if ok else "NO"))
        if not ok:
            line(fp, out.rstrip())
            results.append({
                "label": label,
                "arch": arch,
                "present": False,
                "analyzed": False,
                "client_symbols": [],
                "protocol_hits": 0,
                "server_symbol_count": 0,
            })
            continue

        line(fp, "thin_arch=%s" % actual)
        line(fp, "slice_sha256=%s" % sha256(thin))

        rc, deps = run(["/usr/bin/otool", "-L", thin])
        line(fp, "-- dependencies --")
        line(fp, deps.rstrip())

        rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
        if rc != 0:
            line(fp, "-- nm failed --")
            line(fp, nm_out.rstrip())
            results.append({
                "label": label,
                "arch": arch,
                "present": True,
                "analyzed": False,
                "client_symbols": [],
                "protocol_hits": 0,
                "server_symbol_count": 0,
            })
            continue

        symbols = parse_symbols(nm_out)
        line(fp)
        line(fp, "-- focused symbols/imports --")
        focused = [x for x in nm_out.splitlines() if FOCUS_RE.search(x)]
        for x in focused[:2200]:
            line(fp, x)
        if len(focused) > 2200:
            line(fp, "additional_focused_symbol_lines_omitted=%d" %
                 (len(focused) - 2200))

        emit_focused_strings(fp, thin)

        line(fp)
        line(fp, "-- raw status-value inventory --")
        for err_label, value in ERROR_VALUES:
            raw_value_hits(fp, thin, err_label, value)

        rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
        if rc != 0:
            line(fp, "-- disassembly failed --")
            line(fp, dis_out.rstrip())
            results.append({
                "label": label,
                "arch": arch,
                "present": True,
                "analyzed": False,
                "client_symbols": [],
                "protocol_hits": 0,
                "server_symbol_count": 0,
            })
            continue

        rows = parse_instructions(dis_out)
        protocol_hits, protocol_owners = emit_protocol_range_instruction_inventory(
            fp, rows, symbols)

        found_client_symbols = []
        if label == "FontRegistry":
            line(fp)
            line(fp, "-- exact rendezvous client symbol inventory --")
            for wanted in CLIENT_SYMBOLS:
                addrs = symbol_addresses(symbols, wanted)
                line(fp, "%s count=%d%s" %
                     (wanted,
                      len(addrs),
                      "" if not addrs else
                      " addresses=" + ",".join("0x%x" % a for a, n in addrs)))
                for addr, name in addrs:
                    found_client_symbols.append(name)
                    emit_function_window(fp, rows, symbols, addr, name)

        server_symbol_count = 0
        if label == "ATSServer":
            line(fp)
            line(fp, "-- rendezvous/server symbol inventory --")
            candidates = [(addr, name) for addr, name in symbols
                          if SERVER_SYMBOL_RE.search(name)]
            server_symbol_count = len(candidates)
            line(fp, "matching_server_symbols=%d" % server_symbol_count)
            for addr, name in candidates[:240]:
                line(fp, "server_symbol=0x%x %s" % (addr, name))
            if len(candidates) > 240:
                line(fp, "additional_server_symbols_omitted=%d" %
                     (len(candidates) - 240))

            emitted = {}
            for addr, name in candidates[:120]:
                key = (addr, name)
                if key in emitted:
                    continue
                emitted[key] = True
                emit_function_window(fp, rows, symbols, addr, name)

            for owner in sorted(protocol_owners.keys()):
                if owner in emitted:
                    continue
                addr, name = owner
                emitted[owner] = True
                emit_function_window(fp, rows, symbols, addr, name)

        results.append({
            "label": label,
            "arch": arch,
            "present": True,
            "analyzed": True,
            "client_symbols": sorted(set(found_client_symbols)),
            "protocol_hits": len(protocol_hits),
            "server_symbol_count": server_symbol_count,
        })

    return results


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="pm-fontserver-rendezvous-v2.")
    issues = []

    try:
        _, product = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product.strip()
        build = build.strip()

        if product == "10.6.8":
            client_required_arch = "ppc7400"
            arches = ["ppc7400", "i386", "x86_64"]
            required_client_symbol = "_XTSendRendezvous"
        elif product == "10.7.5":
            client_required_arch = "i386"
            arches = ["i386", "x86_64"]
            required_client_symbol = "_XTSendRendezvous2"
        else:
            client_required_arch = None
            arches = []
            required_client_symbol = None
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            line(fp, "== Process Manager FontServer rendezvous protocol audit v2 ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)

            line(fp)
            line(fp, "== Established dynamic discriminator ==")
            line(fp, "snow_legacy_rendezvous_request=0x000032c8")
            line(fp, "snow_send_receive=0x18/0x3c")
            line(fp, "snow_reply=0x0000332c size=0x34 complex=YES")
            line(fp, "lion_translated_same_request=0x000032c8")
            line(fp, "lion_translated_reply=0x0000332c size=0x24 complex=NO")
            line(fp, "lion_translated_raw_status_bytes=65fdffff")
            line(fp, "lion_translated_status_interpretation=0xfffffd65 signed=-667")
            line(fp, "prior_v1_snow_symbol=_XTSendRendezvous")
            line(fp, "prior_v1_lion_symbol=_XTSendRendezvous2")
            line(fp, "prior_v1_lion_raw_0x32c8_in_FontRegistry=0")
            line(fp, "purpose=decode native Lion rendezvous replacement and server-side protocol")

            results = []
            results.extend(analyze_image(
                fp, "FontRegistry", FONTREGISTRY, arches, tempdir))
            results.extend(analyze_image(
                fp, "ATSServer", ATSSERVER, arches, tempdir))

            line(fp)
            line(fp, "== Audit validation ==")

            client = None
            server_analyzed = 0
            server_protocol_hits = 0
            for result in results:
                if (result["label"] == "FontRegistry" and
                        result["arch"] == client_required_arch):
                    client = result
                if result["label"] == "ATSServer" and result["analyzed"]:
                    server_analyzed += 1
                    server_protocol_hits += result["protocol_hits"]

            if client_required_arch is not None:
                if client is None or not client["present"] or not client["analyzed"]:
                    issues.append("required FontRegistry/%s slice not analyzable" %
                                  client_required_arch)
                elif required_client_symbol not in client["client_symbols"]:
                    issues.append("required rendezvous client symbol missing: %s" %
                                  required_client_symbol)

            if not os.path.isfile(ATSSERVER):
                issues.append("libATSServer.dylib missing")
            elif server_analyzed == 0:
                issues.append("no libATSServer slice could be analyzed")

            line(fp, "required_client_arch=%s" % client_required_arch)
            line(fp, "required_client_symbol=%s" % required_client_symbol)
            line(fp, "server_analyzed_slices=%d" % server_analyzed)
            line(fp, "server_protocol_range_instruction_hits=%d" %
                 server_protocol_hits)

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
            line(fp, "No launchd job or font service was started, stopped, restarted, or signaled.")
            line(fp, "No FontRegistry, libATSServer, fontd, Rosetta, cache, or XNU file was modified.")
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
