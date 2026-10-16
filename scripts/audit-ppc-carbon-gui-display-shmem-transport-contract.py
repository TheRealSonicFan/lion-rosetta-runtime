#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-transport-contract-v1"

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

COMMON_TARGETS = [
    "__CGSGetDisplayShmem",
    "_CGSResolveShmemReference",
    "_CGSServerPort",
    "_CGSScoreboard",
    "_CGSGetDenyWindowServerConnections",
    "_lookupMainDisplay",
]

RELEASE_INIT = {
    "snow": "_initCGDisplayState",
    "lion": "_initDisplayState",
}

RELEASE_MAPPING = {
    "snow": "_initCGDisplayMappings",
    "lion": "_initDisplayMappings",
}

MIG_RE = re.compile(
    r"(mach_msg|mig_get_reply_port|mig_put_reply_port|mig_dealloc_reply_port|"
    r"MIG_|NDR|ndr)", re.I
)
CALL_RE = re.compile(r"\b(calll|callq|bl|b|jmp)\b", re.I)
HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")
CALL_TARGET_RE = re.compile(
    r"\b(?:calll|callq|bl|b|jmp)\s+(?:\*?)(0x[0-9a-fA-F]+)", re.I
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


def branch_target(raw):
    m = CALL_TARGET_RE.search(raw)
    if not m:
        return None
    try:
        return int(m.group(1), 16)
    except ValueError:
        return None


def resolved_calls(selected, address_to_symbol):
    result = []
    for addr, raw in selected:
        if not CALL_RE.search(raw):
            continue
        target = branch_target(raw)
        name = None
        if target is not None:
            name = address_to_symbol.get(target)
        result.append((addr, raw, target, name))
    return result


def calls_target(selected, target_name, target_addr):
    name_lower = target_name.lower()
    forms = ["0x%x" % target_addr, "0x%08x" % target_addr]
    for addr, raw in selected:
        low = raw.lower()
        if name_lower in low:
            return True
        if any(form.lower() in low for form in forms):
            return True
        target = branch_target(raw)
        if target == target_addr:
            return True
    return False


def direct_references(symbols, groups, target_idx):
    target_addr, target_name, raw_symbol = symbols[target_idx]
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
                continue
            target = branch_target(call_raw)
            if target == target_addr:
                hits.append((idx, call_addr, call_raw))
    return hits


def protocol_value(value):
    if 0x7000 <= value <= 0x7fff:
        return True
    if value == 0x1513:
        return True
    if value in (
        0x3, 0x18, 0x1c, 0x20, 0x24, 0x28, 0x2c, 0x30, 0x34,
        0x38, 0x3c, 0x40, 0x44, 0x48, 0x50, 0x58, 0x60, 0x68,
        0x70, 0x78, 0x80, 0x88, 0x90, 0x98, 0xa0, 0xc30, 0x4030
    ):
        return True
    return False


def emit_symbol(fp, label, symbols, groups, address_to_symbol, idx):
    addr, name, raw = symbols[idx]
    selected = groups.get(idx, [])
    calls = resolved_calls(selected, address_to_symbol)
    mig = [r for a, r in selected if MIG_RE.search(r)]
    refs = direct_references(symbols, groups, idx)

    line(fp)
    line(fp, "== %s: %s ==" % (label, name))
    line(fp, "symbol_address=0x%x" % addr)
    line(fp, "symbol_record=%s" % raw)
    line(fp, "instruction_lines=%d" % len(selected))
    line(fp, "call_or_branch_line_count=%d" % len(calls))
    line(fp, "mig_transport_line_count=%d" % len(mig))

    for a, r in selected:
        line(fp, r)

    line(fp, "-- resolved calls/branches --")
    if calls:
        for call_addr, call_raw, target, resolved in calls:
            if target is None:
                line(fp, "call_site=0x%x target=UNRESOLVED raw=%s" %
                     (call_addr, call_raw))
            else:
                line(fp, "call_site=0x%x target=0x%x resolved=%s raw=%s" %
                     (call_addr, target, resolved or "UNKNOWN", call_raw))
    else:
        line(fp, "NONE")

    line(fp, "-- Mach/MIG lines --")
    if mig:
        for r in mig:
            line(fp, r)
    else:
        line(fp, "NONE")

    line(fp, "-- protocol-bearing immediates --")
    values = []
    seen = set()
    for a, r in selected:
        for token in HEX_RE.findall(r):
            try:
                value = int(token, 16)
            except ValueError:
                continue
            if protocol_value(value) and (value, r) not in seen:
                seen.add((value, r))
                values.append((value, r))
    if values:
        for value, raw_line in values:
            line(fp, "value=0x%08x line=%s" % (value, raw_line))
    else:
        line(fp, "NONE")

    line(fp, "direct_reference_count=%d" % len(refs))
    for caller_idx, call_addr, call_raw in refs[:400]:
        line(fp, "caller=%s@0x%x call_site=0x%x raw=%s" %
             (symbols[caller_idx][1], symbols[caller_idx][0],
              call_addr, call_raw))


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-shmem.")

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
            line(fp, "== PPC Carbon GUI display-shmem transport contract audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
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
                    address_to_symbol = {}
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

                    address_to_symbol = {}
                    for saddr, sname, sraw in symbols:
                        address_to_symbol[saddr] = sname

                    init_name = RELEASE_INIT[mode]
                    mapping_name = RELEASE_MAPPING[mode]
                    targets = [init_name, mapping_name] + COMMON_TARGETS

                    line(fp)
                    line(fp, "== Required target inventory ==")
                    target_indexes = {}
                    for name in targets:
                        idxs = exact_indices(symbols, name)
                        target_indexes[name] = idxs
                        line(fp, "target=%s count=%d" % (name, len(idxs)))
                        for idx in idxs:
                            line(fp, "%s@0x%x" % (symbols[idx][1], symbols[idx][0]))
                        if len(idxs) != 1:
                            issues.append("expected exactly one target: %s" % name)

                    emitted = set()
                    for name in targets:
                        for idx in target_indexes.get(name, []):
                            if idx in emitted:
                                continue
                            emitted.add(idx)
                            emit_symbol(fp, "CoreGraphics target", symbols, groups,
                                        address_to_symbol, idx)

                    if len(target_indexes.get(init_name, [])) == 1:
                        init_idx = target_indexes[init_name][0]
                        init_rows = groups.get(init_idx, [])
                        get_idxs = target_indexes.get("__CGSGetDisplayShmem", [])
                        resolve_idxs = target_indexes.get("_CGSResolveShmemReference", [])
                        server_idxs = target_indexes.get("_CGSServerPort", [])

                        if len(get_idxs) == 1:
                            ok = calls_target(
                                init_rows, "__CGSGetDisplayShmem",
                                symbols[get_idxs[0]][0])
                            line(fp, "init_calls_get_display_shmem=%s" %
                                 ("YES" if ok else "NO"))
                            if not ok:
                                issues.append("%s does not call __CGSGetDisplayShmem" %
                                              init_name)

                        if len(resolve_idxs) == 1:
                            ok = calls_target(
                                init_rows, "_CGSResolveShmemReference",
                                symbols[resolve_idxs[0]][0])
                            line(fp, "init_calls_resolve_shmem_reference=%s" %
                                 ("YES" if ok else "NO"))
                            if not ok:
                                issues.append("%s does not call _CGSResolveShmemReference" %
                                              init_name)

                        if len(server_idxs) == 1:
                            ok = calls_target(
                                init_rows, "_CGSServerPort",
                                symbols[server_idxs[0]][0])
                            line(fp, "init_calls_cgs_server_port=%s" %
                                 ("YES" if ok else "NO"))
                            if not ok:
                                issues.append("%s does not call _CGSServerPort" %
                                              init_name)

                    if len(target_indexes.get("__CGSGetDisplayShmem", [])) == 1:
                        get_idx = target_indexes["__CGSGetDisplayShmem"][0]
                        get_rows = groups.get(get_idx, [])
                        has_mig = any(MIG_RE.search(raw) for a, raw in get_rows)
                        line(fp, "get_display_shmem_has_mach_mig_transport=%s" %
                             ("YES" if has_mig else "NO"))
                        if not has_mig:
                            issues.append("__CGSGetDisplayShmem has no visible Mach/MIG transport")

            line(fp)
            line(fp, "== Comparison questions ==")
            line(fp, "question_1=What exact generated-MIG request/reply IDs does __CGSGetDisplayShmem use on this release?")
            line(fp, "question_2=Are Mach bits, options, request size, receive size, NDR handling, and reply validation identical across Snow and Lion?")
            line(fp, "question_3=If IDs differ, is the change ID-only or accompanied by request/reply schema changes?")
            line(fp, "question_4=What shared-memory references are returned to the display-state initializer and which _CGSResolveShmemReference modes consume them?")
            line(fp, "question_5=Which single live observation can prove the translated Snow initializer reaches or fails this boundary without rewriting a display ID?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_transport_contract_audit_exact=YES")
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
