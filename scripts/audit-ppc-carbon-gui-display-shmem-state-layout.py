#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-state-layout-v1"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

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

TARGETS = {
    "snow": [
        "_initCGDisplayState",
        "_initCGDisplayMappings",
        "_bindDisplayMapping",
        "_lookupMainDisplay",
        "_lookupDisplay",
        "_CGSMainDisplayID",
        "__CGSGetDisplayShmem",
        "_CGSResolveShmemReference",
        "__XGetDisplayShmem",
    ],
    "lion": [
        "_initDisplayState",
        "_initDisplayMappings",
        "_addEntryForDisplay",
        "_lookupMainDisplay",
        "_lookupDisplay",
        "_lookupDisplayNumber",
        "_CGSMainDisplayID",
        "__CGSGetDisplayShmem",
        "_CGSResolveShmemReference",
        "__XGetDisplayShmem",
        "__CGXGetDisplayShmem",
    ],
}

MAPPING_TARGET = {
    "snow": "_initCGDisplayMappings",
    "lion": "_initDisplayMappings",
}

EXPECTED_MAPPING_IMMEDIATES = {
    "snow": [0x20, 0x58, 0x150],
    "lion": [0x20, 0x68, 0x138, 0x170, 0x17c],
}

CALL_RE = re.compile(r"\b(bl|b|calll|callq|jmp)\b", re.I)
HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")
FOCUS_STRING_RE = re.compile(
    r"(display info mapping|display mapping|CGSMainDisplayID|"
    r"Invalid display|Cannot get displays|GetDisplayShmem)",
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
    return [i for i, item in enumerate(symbols) if item[1] == name]


def direct_references(symbols, groups, target_idx):
    target_addr, target_name, raw = symbols[target_idx]
    forms = ["0x%x" % target_addr, "0x%08x" % target_addr]
    low_name = target_name.lower()
    hits = []
    for idx, selected in groups.items():
        if idx == target_idx:
            continue
        for call_addr, call_raw in selected:
            low = call_raw.lower()
            if low_name in low or any(form.lower() in low for form in forms):
                hits.append((idx, call_addr, call_raw))
    return hits


def immediate_values(selected):
    values = {}
    for addr, raw in selected:
        for token in HEX_RE.findall(raw):
            try:
                value = int(token, 16)
            except ValueError:
                continue
            values.setdefault(value, []).append((addr, raw))
    return values


def emit_symbol(fp, symbols, groups, idx):
    addr, name, raw = symbols[idx]
    selected = groups.get(idx, [])
    calls = [r for a, r in selected if CALL_RE.search(r)]
    refs = direct_references(symbols, groups, idx)
    values = immediate_values(selected)

    line(fp)
    line(fp, "== CoreGraphics target: %s ==" % name)
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "symbol_record=%s" % raw)
    line(fp, "instruction_lines=%d" % len(selected))
    line(fp, "call_or_branch_line_count=%d" % len(calls))
    for a, r in selected:
        line(fp, r)

    line(fp, "-- call/branch subset --")
    if calls:
        for r in calls:
            line(fp, r)
    else:
        line(fp, "NONE")

    line(fp, "-- layout-bearing immediate inventory --")
    interesting = [v for v in sorted(values.keys())
                   if v <= 0x400 and v >= 0x10]
    if interesting:
        for value in interesting:
            hits = values[value]
            line(fp, "immediate=0x%08x count=%d" % (value, len(hits)))
            for hit_addr, hit_raw in hits[:40]:
                line(fp, "  at=0x%x raw=%s" % (hit_addr, hit_raw))
    else:
        line(fp, "NONE")

    line(fp, "direct_reference_count=%d" % len(refs))
    for caller_idx, call_addr, call_raw in refs[:400]:
        line(fp, "caller=%s@0x%x call_site=0x%x raw=%s" %
             (symbols[caller_idx][1], symbols[caller_idx][0],
              call_addr, call_raw))


def emit_strings(fp, path):
    rc, out = run(["/usr/bin/strings", "-a", path])
    line(fp)
    line(fp, "== Focused strings ==")
    if rc != 0:
        line(fp, "strings_failed")
        return
    hits = [s for s in out.splitlines() if FOCUS_STRING_RE.search(s)]
    line(fp, "focused_string_count=%d" % len(hits))
    for s in hits[:500]:
        line(fp, s)


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-shmem-layout.")

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
            line(fp, "== PPC Carbon GUI display shared-state layout audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "display_shmem_wire_relation=IDENTICAL_FROM_PRIOR_AUDIT")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
            line(fp, "display_shmem_adapter_authorized=NO")
            line(fp, "display_mapping_patch_authorized=NO")
            line(fp, "event_payload_rewrite_authorized=NO")
            line(fp, "move_payload_rewrite_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            line(fp)
            line(fp, "== Rosetta shared-cache provenance ==")
            if os.path.isfile(ROSETTA_CACHE):
                line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
            else:
                line(fp, "rosetta_cache=MISSING")
            if os.path.isfile(ROSETTA_MAP):
                line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
                try:
                    data = open(ROSETTA_MAP, "r").read()
                    line(fp, "cache_map_contains_coregraphics=%s" %
                         ("YES" if COREGRAPHICS in data else "NO"))
                except IOError as e:
                    line(fp, "rosetta_cache_map_read_error=%s" % e)
            else:
                line(fp, "rosetta_cache_map=MISSING")

            line(fp)
            line(fp, "== CoreGraphics ==")
            line(fp, "path=%s" % COREGRAPHICS)
            if not os.path.isfile(COREGRAPHICS):
                line(fp, "state=MISSING")
                issues.append("CoreGraphics missing")
            elif arch is not None:
                line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                rc, out = run(["/usr/bin/file", COREGRAPHICS])
                line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREGRAPHICS])
                line(fp, out.rstrip())

                dst = os.path.join(tempdir, "CoreGraphics." + arch)
                ok, out = thin(COREGRAPHICS, arch, dst)
                line(fp, "thin=%s" % ("YES" if ok else "NO"))
                if not ok:
                    line(fp, out.rstrip())
                    issues.append("required CoreGraphics slice missing")
                    symbols = []
                    groups = {}
                else:
                    slice_hash = sha256(dst)
                    line(fp, "slice_sha256=%s" % slice_hash)
                    line(fp, "slice_exact=%s" %
                         ("YES" if slice_hash == EXPECTED_SLICE[mode] else "NO"))
                    if slice_hash != EXPECTED_SLICE[mode]:
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

                    emit_strings(fp, dst)

                    line(fp)
                    line(fp, "== Required target inventory ==")
                    target_indexes = {}
                    for name in TARGETS[mode]:
                        idxs = exact_indices(symbols, name)
                        target_indexes[name] = idxs
                        line(fp, "target=%s count=%d" % (name, len(idxs)))
                        for idx in idxs:
                            line(fp, "%s@0x%x" %
                                 (symbols[idx][1], symbols[idx][0]))
                        if len(idxs) != 1:
                            issues.append("expected exactly one target: %s" % name)

                    for name in TARGETS[mode]:
                        for idx in target_indexes.get(name, []):
                            emit_symbol(fp, symbols, groups, idx)

                    mapping_name = MAPPING_TARGET[mode]
                    mapping_idxs = target_indexes.get(mapping_name, [])
                    if len(mapping_idxs) == 1:
                        selected = groups.get(mapping_idxs[0], [])
                        values = immediate_values(selected)
                        line(fp)
                        line(fp, "== Mapping-layout discriminator ==")
                        for value in EXPECTED_MAPPING_IMMEDIATES[mode]:
                            present = value in values
                            line(fp, "mapping_immediate_0x%03x=%s" %
                                 (value, "YES" if present else "NO"))
                            if present:
                                for hit_addr, hit_raw in values[value][:20]:
                                    line(fp, "  at=0x%x raw=%s" %
                                         (hit_addr, hit_raw))
                            else:
                                issues.append("%s missing expected immediate 0x%x" %
                                              (mapping_name, value))

                        if mode == "snow":
                            line(fp, "mapped_display_record_stride=0x150")
                            line(fp, "local_mapping_record_stride=0x58")
                            line(fp, "mapped_display_record_base_offset=0x20")
                        else:
                            line(fp, "mapped_display_record_stride=0x17c")
                            line(fp, "local_mapping_record_stride=0x68")
                            line(fp, "mapped_display_record_base_offset=0x20")
                            line(fp, "mapped_display_record_field_0x138=REFERENCED")
                            line(fp, "mapped_display_record_field_0x170=REFERENCED")

            line(fp)
            line(fp, "== Comparison questions ==")
            line(fp, "question_1=What exact count/header fields precede the mapped per-display records on each release?")
            line(fp, "question_2=Which per-display offsets supply display identity, active/main state, bounds, and mapping metadata?")
            line(fp, "question_3=Does Snow walk mapped display records with a 0x150 stride while Lion walks them with a 0x17c stride?")
            line(fp, "question_4=Which Lion-only fields at or beyond 0x150 cause a translated Snow reader to become misaligned after the first record?")
            line(fp, "question_5=How do __XGetDisplayShmem and __CGXGetDisplayShmem expose the server-owned mappings and reference pairs on each release?")
            line(fp, "question_6=After resolving the record schema, what single passive live observation can distinguish a valid mapped object from a legacy-layout parse failure?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_state_layout_audit_exact=YES")
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
