#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-record-writer-layout-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

SNOW_PRODUCT = "10.6.8"
SNOW_BUILD = "10K549"
LION_PRODUCT = "10.7.5"
LION_BUILD = "11G63"
SNOW_ARCH = "ppc7400"
LION_ARCH = "i386"

EXPECTED_SLICE = {
    "snow": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
    "lion": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
}

COMMON_TARGETS = [
    "_CGXMainDisplayDevice",
    "_markNewMainDisplay",
    "_lookupMainDisplay",
    "_lookupMasterDisplay",
    "_CGSDisplayStatusQuery",
    "_CGXDisplayDriverInitialize",
    "_CGXPerformInitialDisplayConfiguration",
    "_reconfigureDisplays",
    "_get_active_display_list",
    "_logOneDisplayState",
    "_VFBGetMonitorInfo",
    "_MPGetMonitorInfo",
    "_CGXDeviceStateChanged",
    "_CGXConstructVirtualFramebuffer",
]

EXTRA_TARGETS = {
    "snow": ["_display_connect_change"],
    "lion": ["_displayConnectChange", "_displayAliasActivate"],
}

MAIN_FIELDS = {
    "snow": [0x0f4, 0x0f8, 0x10c, 0x10d, 0x10e, 0x110, 0x111, 0x112, 0x113],
    "lion": [0x110, 0x114, 0x128, 0x129, 0x12a, 0x12c, 0x12d, 0x12e, 0x12f],
}

RECORD_RANGE = {
    "snow": (0x0e0, 0x150),
    "lion": (0x0e0, 0x17c),
}

HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")


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


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def parse_hex(token):
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
    return False, out2 if out2.strip() else out


def thin(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out


def parse_symbols(text):
    result = []
    for raw in text.splitlines():
        if "(__TEXT,__text)" not in raw:
            continue
        parts = raw.split()
        if len(parts) < 2:
            continue
        addr = parse_hex(parts[0])
        if addr is None:
            continue
        result.append((addr, parts[-1], raw))
    result.sort()
    return result


def parse_rows(text):
    rows = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex(parts[0])
        if addr is not None:
            rows.append((addr, raw))
    return rows


def group_rows(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for addr, raw in rows:
        while si + 1 < len(symbols) and symbols[si + 1][0] <= addr:
            si += 1
        if symbols[si][0] <= addr:
            groups.setdefault(si, []).append((addr, raw))
    return groups


def exact_indices(symbols, name):
    result = []
    for i, item in enumerate(symbols):
        if item[1] == name:
            result.append(i)
    return result


def instruction_values(raw):
    parts = raw.split(None, 1)
    body = parts[1] if len(parts) > 1 else ""
    result = []
    for token in HEX_RE.findall(body):
        try:
            result.append(int(token, 16))
        except ValueError:
            pass
    return result


def offsets_in_range(raw, lo, hi):
    result = []
    for value in instruction_values(raw):
        if lo <= value < hi and value not in result:
            result.append(value)
    return result


def target_offsets(selected, lo, hi):
    values = []
    for addr, raw in selected:
        for value in offsets_in_range(raw, lo, hi):
            if value not in values:
                values.append(value)
    values.sort()
    return values


def target_has_field(selected, value):
    for addr, raw in selected:
        if value in instruction_values(raw):
            return True
    return False


def emit_target(fp, name, symbols, groups, idx, lo, hi):
    addr, sym_name, raw = symbols[idx]
    selected = groups.get(idx, [])
    offsets = target_offsets(selected, lo, hi)

    line(fp)
    line(fp, "== Record-range target: %s ==" % name)
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "symbol_record=%s" % raw)
    line(fp, "instruction_lines=%d" % len(selected))
    line(fp, "record_range=0x%03x-0x%03x" % (lo, hi - 1))
    line(fp, "record_range_offset_count=%d" % len(offsets))
    if offsets:
        line(fp, "record_range_offsets=%s" %
             ",".join(["0x%03x" % value for value in offsets]))
    else:
        line(fp, "record_range_offsets=NONE")

    line(fp, "-- matched instruction contexts --")
    hit_count = 0
    for i, item in enumerate(selected):
        addr2, raw2 = item
        vals = offsets_in_range(raw2, lo, hi)
        if not vals:
            continue
        hit_count += 1
        start = max(0, i - 2)
        end = min(len(selected), i + 3)
        line(fp, "hit=%d instruction=0x%x offsets=%s" %
             (hit_count, addr2,
              ",".join(["0x%03x" % value for value in vals])))
        for j in range(start, end):
            marker = ">" if j == i else " "
            line(fp, "%s %s" % (marker, selected[j][1]))

    line(fp, "record_range_hit_count=%d" % hit_count)


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-writer-layout.")

    try:
        rc, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip() if rc == 0 else "UNKNOWN"
        rc, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip() if rc == 0 else "UNKNOWN"

        if product == SNOW_PRODUCT and build == SNOW_BUILD:
            mode = "snow"
            arch = SNOW_ARCH
        elif product == LION_PRODUCT and build == LION_BUILD:
            mode = "lion"
            arch = LION_ARCH
        else:
            mode = "unsupported"
            arch = None
            issues.append("unsupported product/build: %s/%s" % (product, build))

        with open(report, "w") as fp:
            line(fp, "== PPC Carbon GUI display-shmem record writer-layout audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "prior_wire_relation=IDENTICAL")
            line(fp, "prior_main_semantic_shift=0x1c")
            line(fp, "prior_source_record_growth=0x2c")
            line(fp, "passive_snapshot_authorized=NO")
            line(fp, "shared_record_rewrite_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
            line(fp, "display_shmem_adapter_authorized=NO")
            line(fp, "event_payload_rewrite_authorized=NO")
            line(fp, "move_payload_rewrite_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            line(fp)
            line(fp, "== CoreGraphics ==")
            line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                line(fp, "state=MISSING")
                issues.append("CoreGraphics missing")
            elif arch is not None:
                line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                dst = os.path.join(tempdir, "CoreGraphics." + arch)
                ok, out = thin(COREGRAPHICS, arch, dst)
                line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing")
                else:
                    slice_hash = sha256(dst)
                    line(fp, "slice_sha256=%s" % slice_hash)
                    exact = slice_hash == EXPECTED_SLICE[mode]
                    line(fp, "slice_exact=%s" % ("YES" if exact else "NO"))
                    if not exact:
                        issues.append("CoreGraphics slice SHA-256 mismatch")

                    rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                    if rc != 0:
                        line(fp, "nm_failed")
                        line(fp, nm_out.rstrip())
                        issues.append("nm failed")
                        symbols = []
                    else:
                        symbols = parse_symbols(nm_out)
                        line(fp, "parsed_text_symbols=%d" % len(symbols))

                    rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                    if rc != 0:
                        line(fp, "otool_disassembly_failed")
                        line(fp, dis_out.rstrip())
                        issues.append("otool disassembly failed")
                        groups = {}
                    else:
                        rows = parse_rows(dis_out)
                        groups = group_rows(rows, symbols)
                        line(fp, "parsed_instruction_lines=%d" % len(rows))

                    targets = list(COMMON_TARGETS) + list(EXTRA_TARGETS[mode])
                    line(fp)
                    line(fp, "== Required target inventory ==")
                    for name in targets:
                        idxs = exact_indices(symbols, name)
                        line(fp, "target=%s count=%d" % (name, len(idxs)))
                        for idx in idxs:
                            line(fp, "%s@0x%x" %
                                 (symbols[idx][1], symbols[idx][0]))
                        if len(idxs) != 1:
                            issues.append("expected exactly one target: %s" % name)

                    lo, hi = RECORD_RANGE[mode]
                    for name in targets:
                        idxs = exact_indices(symbols, name)
                        if len(idxs) == 1:
                            emit_target(fp, name, symbols, groups, idxs[0], lo, hi)

                    line(fp)
                    line(fp, "== Main-display anchor validation ==")
                    idxs = exact_indices(symbols, "_lookupMainDisplay")
                    if len(idxs) == 1:
                        selected = groups.get(idxs[0], [])
                        for value in MAIN_FIELDS[mode]:
                            present = target_has_field(selected, value)
                            line(fp, "lookup_main_field_0x%03x=%s" %
                                 (value, "YES" if present else "NO"))
                            if not present:
                                issues.append("_lookupMainDisplay missing field 0x%x" % value)

            line(fp)
            line(fp, "== Cross-release questions ==")
            line(fp, "question_1=Within same-named display-device writers/readers, where does the Snow-to-Lion field displacement first become +0x1c?")
            line(fp, "question_2=Where does the additional +0x10 of Lion record growth appear relative to that +0x1c block shift?")
            line(fp, "question_3=Which fields are consistently read/written by CGXDisplayDriverInitialize, CGXPerformInitialDisplayConfiguration, and reconfigureDisplays on both releases?")
            line(fp, "question_4=Do Lion 0x118, 0x138, 0x154, and 0x170 have stable same-function counterparts in Snow?")
            line(fp, "question_5=Are any apparent same-number references merely stack/local or other-object offsets rather than display-record members?")
            line(fp, "question_6=After writer-side correspondence is resolved, is a passive first-record mapped-state snapshot sufficiently discriminating?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_record_writer_layout_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No display, CGS, WindowServer, Mach, bootstrap, mouse, or notification request was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")
            line(fp, "No CoreGraphics, Rosetta cache, WindowServer, dyld, or XNU state was modified.")

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
