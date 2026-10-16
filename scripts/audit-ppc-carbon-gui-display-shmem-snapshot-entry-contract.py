#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "3"
AUDIT_CONTRACT = "carbon-gui-display-shmem-snapshot-entry-contract-v3"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "targets": [
            "_CGSMainDisplayID",
            "_lookupMainDisplay",
            "_initCGDisplayMappings",
            "_initCGDisplayState",
            "__CGSGetDisplayShmem",
            "_CGSResolveShmemReference",
        ],
        "selector_global_vmaddr": 0x6ff26c,
        "source_array_vmaddr": 0x700460,
        "local_array_vmaddr": 0x700458,
        "mode2_mapping_vmaddr": 0x70046c,
        "lookup_anchor": 0x142b4c,
        "lookup_selector_disp": 0x5bc720,
        "lookup_source_disp": 0x5bd914,
        "lookup_local_disp": 0x5bd90c,
        "mapping_anchor": 0x14288c,
        "mapping_source_disp": 0x5bdbd4,
        "mapping_local_disp": 0x5bdbcc,
        "main_route_addr": 0x148410,
        "main_route_target": "_lookupMainDisplay",
        "mode2_store_addr": 0x140b0c,
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "targets": [
            "_CGSMainDisplayID",
            "_lookupDisplayNumber",
            "_lookupMainDisplay",
            "_initDisplayMappings",
            "_initDisplayState",
            "__CGSGetDisplayShmem",
            "_CGSResolveShmemReference",
        ],
        "selector_global_vmaddr": 0x948630,
        "source_array_vmaddr": 0x94983c,
        "local_array_vmaddr": 0x94984c,
        "mode2_mapping_vmaddr": 0x949848,
        "lookup_anchor": 0x87c3d,
        "lookup_selector_disp": 0x8c09f3,
        "lookup_source_disp": 0x8c1bff,
        "lookup_local_disp": 0x8c1c0f,
        "mapping_anchor": 0xccccd,
        "mapping_source_disp": 0x87cb6f,
        "mapping_local_disp": 0x87cb7f,
        "main_route_addr": 0x87bbe,
        "main_route_target": "_lookupDisplayNumber",
        "mode2_store_addr": 0xccf04,
    },
}

HEX_RE = re.compile(r"^[0-9a-fA-F]+$")


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
    if not token or not HEX_RE.match(token):
        return None
    return int(token, 16)


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True, out
    rc2, out2 = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc2 == 0, out2 if out2.strip() else out


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
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        result.append((addr, parts[-1], raw))
    result.sort()
    return result


def parse_rows(text):
    result = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            result.append((addr, raw))
    return result


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


def text_vmaddr(otool_load):
    lines = otool_load.splitlines()
    for i, raw in enumerate(lines):
        if raw.strip() == "segname __TEXT":
            for j in range(i + 1, min(i + 12, len(lines))):
                parts = lines[j].strip().split()
                if len(parts) == 2 and parts[0] == "vmaddr":
                    try:
                        return int(parts[1], 16)
                    except ValueError:
                        return None
    return None


def raw_at(rows, addr):
    for a, raw in rows:
        if a == addr:
            return raw
    return None


def emit_target(fp, symbols, groups, name):
    idxs = exact_indices(symbols, name)
    write_line(fp)
    write_line(fp, "== CoreGraphics target: %s ==" % name)
    write_line(fp, "target_count=%d" % len(idxs))
    if len(idxs) != 1:
        return
    idx = idxs[0]
    addr, sym_name, raw = symbols[idx]
    selected = groups.get(idx, [])
    write_line(fp, "symbol_address=0x%x" % addr)
    write_line(fp, "symbol_record=%s" % raw)
    write_line(fp, "instruction_lines=%d" % len(selected))
    for a, inst in selected:
        write_line(fp, inst)


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-snapshot-entry-v3.")

    try:
        rc, out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = out.strip() if rc == 0 else "UNKNOWN"
        rc, out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = out.strip() if rc == 0 else "UNKNOWN"

        mode = None
        for key, cfg in CONFIG.items():
            if product == cfg["product"] and build == cfg["build"]:
                mode = key
                break

        with open(output, "w") as fp:
            write_line(fp, "== PPC Carbon GUI display-shmem snapshot-entry contract audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "mode=%s" % (mode or "unsupported"))
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "v1_mode2_pointer_misclassification=CORRECTED")
            write_line(fp, "v3_runtime_address_model=DECODE_LOADED_LOOKUPMAIN_PIC")
            write_line(fp, "image_header_plus_standalone_vmaddr_authorized=NO")
            write_line(fp, "passive_snapshot_authorized=NO")
            write_line(fp, "live_probe_authorized=NO")
            write_line(fp, "shared_record_rewrite_authorized=NO")
            write_line(fp, "display_id_substitution_authorized=NO")
            write_line(fp, "display_id_normalization_authorized=NO")
            write_line(fp, "display_shmem_adapter_authorized=NO")
            write_line(fp, "xnu_change_authorized=NO")

            if mode is None:
                issues.append("unsupported product/build")
            else:
                cfg = CONFIG[mode]
                write_line(fp, "required_arch=%s" % cfg["arch"])
                write_line(fp, "expected_slice_sha256=%s" % cfg["slice_sha256"])

                if not os.path.isfile(COREGRAPHICS):
                    issues.append("CoreGraphics missing")
                else:
                    dst = os.path.join(tempdir, "CoreGraphics." + cfg["arch"])
                    ok, thin_out = thin(COREGRAPHICS, cfg["arch"], dst)
                    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
                    if not ok:
                        write_line(fp, thin_out.rstrip())
                        issues.append("required CoreGraphics slice missing")
                    else:
                        actual = sha256(dst)
                        write_line(fp, "slice_sha256=%s" % actual)
                        exact = actual == cfg["slice_sha256"]
                        write_line(fp, "slice_exact=%s" % ("YES" if exact else "NO"))
                        if not exact:
                            issues.append("CoreGraphics slice SHA-256 mismatch")

                        rc, load_out = run(["/usr/bin/otool", "-l", dst])
                        tvm = text_vmaddr(load_out) if rc == 0 else None
                        if tvm is None:
                            issues.append("could not resolve __TEXT vmaddr")
                            write_line(fp, "text_vmaddr=UNKNOWN")
                        else:
                            write_line(fp, "text_vmaddr=0x%x" % tvm)

                        rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                        symbols = parse_symbols(nm_out) if rc == 0 else []
                        if rc != 0:
                            issues.append("nm failed")

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                        rows = parse_rows(dis_out) if rc == 0 else []
                        groups = group_rows(rows, symbols) if rc == 0 else {}
                        if rc != 0:
                            issues.append("otool disassembly failed")

                        write_line(fp)
                        write_line(fp, "== Required target inventory ==")
                        for name in cfg["targets"]:
                            idxs = exact_indices(symbols, name)
                            write_line(fp, "target=%s count=%d" % (name, len(idxs)))
                            if len(idxs) != 1:
                                issues.append("expected exactly one target: %s" % name)

                        main_idxs = exact_indices(symbols, "_CGSMainDisplayID")
                        resolve_idxs = exact_indices(symbols, "_CGSResolveShmemReference")
                        get_idxs = exact_indices(symbols, "__CGSGetDisplayShmem")
                        main_external = len(main_idxs) == 1 and " external " in (" " + symbols[main_idxs[0]][2] + " ")
                        resolve_external = len(resolve_idxs) == 1 and " external " in (" " + symbols[resolve_idxs[0]][2] + " ")
                        get_nonexternal = len(get_idxs) == 1 and "non-external" in symbols[get_idxs[0]][2]

                        write_line(fp)
                        write_line(fp, "== Corrected snapshot-source boundary ==")
                        write_line(fp, "main_display_id_external=%s" % ("YES" if main_external else "NO"))
                        write_line(fp, "resolve_shmem_reference_external=%s" % ("YES" if resolve_external else "NO"))
                        write_line(fp, "get_display_shmem_nonexternal=%s" % ("YES" if get_nonexternal else "NO"))
                        if not main_external:
                            issues.append("_CGSMainDisplayID is not external")
                        if not resolve_external:
                            issues.append("_CGSResolveShmemReference is not external")
                        if not get_nonexternal:
                            issues.append("__CGSGetDisplayShmem external-status mismatch")

                        selector_calc = cfg["lookup_anchor"] + cfg["lookup_selector_disp"]
                        source_lookup_calc = cfg["lookup_anchor"] + cfg["lookup_source_disp"]
                        local_lookup_calc = cfg["lookup_anchor"] + cfg["lookup_local_disp"]
                        source_mapping_calc = cfg["mapping_anchor"] + cfg["mapping_source_disp"]
                        local_mapping_calc = cfg["mapping_anchor"] + cfg["mapping_local_disp"]

                        write_line(fp, "selector_global_standalone_vmaddr=0x%x" % cfg["selector_global_vmaddr"])
                        write_line(fp, "selector_global_calculated_standalone_vmaddr=0x%x" % selector_calc)
                        write_line(fp, "selector_global_calculation_exact=%s" % ("YES" if selector_calc == cfg["selector_global_vmaddr"] else "NO"))

                        write_line(fp, "source_array_standalone_vmaddr=0x%x" % cfg["source_array_vmaddr"])
                        write_line(fp, "source_array_lookup_calculated_standalone_vmaddr=0x%x" % source_lookup_calc)
                        write_line(fp, "source_array_mapping_calculated_standalone_vmaddr=0x%x" % source_mapping_calc)
                        source_exact = source_lookup_calc == cfg["source_array_vmaddr"] and source_mapping_calc == cfg["source_array_vmaddr"]
                        write_line(fp, "source_array_calculation_exact=%s" % ("YES" if source_exact else "NO"))

                        write_line(fp, "local_array_standalone_vmaddr=0x%x" % cfg["local_array_vmaddr"])
                        write_line(fp, "local_array_lookup_calculated_standalone_vmaddr=0x%x" % local_lookup_calc)
                        write_line(fp, "local_array_mapping_calculated_standalone_vmaddr=0x%x" % local_mapping_calc)
                        local_exact = local_lookup_calc == cfg["local_array_vmaddr"] and local_mapping_calc == cfg["local_array_vmaddr"]
                        write_line(fp, "local_array_calculation_exact=%s" % ("YES" if local_exact else "NO"))

                        write_line(fp, "mode2_mapping_standalone_vmaddr=0x%x" % cfg["mode2_mapping_vmaddr"])
                        write_line(fp, "mode2_mapping_is_display_source_array=NO")
                        write_line(fp, "standalone_vmaddrs_are_runtime_offsets=NO")
                        write_line(fp, "live_runtime_resolution=DECODE_LOADED_LOOKUPMAIN_PIC")
                        write_line(fp, "source_slot_rule=READ_SELECTOR_BYTE_THEN_SOURCE_ARRAY_PLUS_INDEX_TIMES_4")
                        write_line(fp, "source_slot_count=2")
                        write_line(fp, "snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_DECODE_LOADED_LOOKUPMAIN_PIC_THEN_READ_ACTIVE_SOURCE_ARRAY_SLOT")

                        if selector_calc != cfg["selector_global_vmaddr"]:
                            issues.append("selector-global calculation mismatch")
                        if not source_exact:
                            issues.append("source-array calculation mismatch")
                        if not local_exact:
                            issues.append("local-array calculation mismatch")
                        if cfg["mode2_mapping_vmaddr"] == cfg["source_array_vmaddr"]:
                            issues.append("mode2 pointer unexpectedly aliases source array")

                        route_raw = raw_at(rows, cfg["main_route_addr"])
                        mode2_raw = raw_at(rows, cfg["mode2_store_addr"])
                        write_line(fp, "main_route_raw=%s" % (route_raw or "MISSING"))
                        write_line(fp, "mode2_store_raw=%s" % (mode2_raw or "MISSING"))
                        if route_raw is None or cfg["main_route_target"] not in route_raw:
                            issues.append("_CGSMainDisplayID route mismatch")
                        if mode2_raw is None:
                            issues.append("mode2 store site missing")

                        for name in cfg["targets"]:
                            emit_target(fp, symbols, groups, name)

            write_line(fp)
            write_line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "display_shmem_snapshot_entry_contract_v3_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Integrity ==")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No WindowServer, CGS, display, Mach, mouse, or notification request was issued.")
            write_line(fp, "CoreGraphics was read only.")
            write_line(fp, "Temporary architecture slices were removed on exit.")
            write_line(fp, "No CoreGraphics, Rosetta cache, WindowServer, dyld, or XNU state was modified.")

        print("Created: %s" % output)
        print("RESULT: %s" % ("FAIL" if issues else "PASS"))
        return 1 if issues else 0
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
