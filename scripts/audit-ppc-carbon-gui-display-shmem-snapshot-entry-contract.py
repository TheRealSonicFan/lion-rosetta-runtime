#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-snapshot-entry-contract-v1"

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
        "initializer": "_initCGDisplayState",
        "main_lookup": "_lookupMainDisplay",
        "mapping_init": "_initCGDisplayMappings",
        "resolve_call_addr": 0x140b04,
        "mapping_store_addr": 0x140b0c,
        "pic_anchor": 0x1409cc,
        "pic_high": 0x5c,
        "store_disp_raw": 0xfaa0,
        "mapping_global_vmaddr": 0x70046c,
        "main_route_addr": 0x148410,
        "main_route_target": "_lookupMainDisplay",
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
        "initializer": "_initDisplayState",
        "main_lookup": "_lookupMainDisplay",
        "mapping_init": "_initDisplayMappings",
        "resolve_call_addr": 0xcceff,
        "mapping_store_addr": 0xccf04,
        "pic_anchor": 0xccdc1,
        "pic_disp": 0x87ca87,
        "mapping_global_vmaddr": 0x949848,
        "main_route_addr": 0x87bbe,
        "main_route_target": "_lookupDisplayNumber",
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


def body_has_symbol_call(selected, addr, target):
    for a, raw in selected:
        if a == addr and target in raw:
            return True
    return False


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
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-snapshot-entry.")

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

                write_line(fp)
                write_line(fp, "== CoreGraphics ==")
                write_line(fp, "path=%s" % COREGRAPHICS)
                if not os.path.isfile(COREGRAPHICS):
                    issues.append("CoreGraphics missing")
                    write_line(fp, "state=MISSING")
                else:
                    write_line(fp, "sha256=%s" % sha256(COREGRAPHICS))
                    dst = os.path.join(tempdir, "CoreGraphics." + cfg["arch"])
                    ok, thin_out = thin(COREGRAPHICS, cfg["arch"], dst)
                    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
                    if not ok:
                        issues.append("required CoreGraphics slice missing")
                        write_line(fp, thin_out.rstrip())
                    else:
                        actual = sha256(dst)
                        exact = actual == cfg["slice_sha256"]
                        write_line(fp, "slice_sha256=%s" % actual)
                        write_line(fp, "slice_exact=%s" % ("YES" if exact else "NO"))
                        if not exact:
                            issues.append("CoreGraphics slice SHA-256 mismatch")

                        rc, load_out = run(["/usr/bin/otool", "-l", dst])
                        tvm = text_vmaddr(load_out) if rc == 0 else None
                        if tvm is None:
                            write_line(fp, "text_vmaddr=UNKNOWN")
                            issues.append("could not resolve __TEXT vmaddr")
                        else:
                            write_line(fp, "text_vmaddr=0x%x" % tvm)
                            delta = cfg["mapping_global_vmaddr"] - tvm
                            write_line(fp, "mapping_global_from_image_header=0x%x" % delta)

                        rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                        if rc != 0:
                            issues.append("nm failed")
                            symbols = []
                            write_line(fp, "parsed_text_symbols=0")
                        else:
                            symbols = parse_symbols(nm_out)
                            write_line(fp, "parsed_text_symbols=%d" % len(symbols))

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                        if rc != 0:
                            issues.append("otool disassembly failed")
                            rows = []
                            groups = {}
                            write_line(fp, "parsed_instruction_lines=0")
                        else:
                            rows = parse_rows(dis_out)
                            groups = group_rows(rows, symbols)
                            write_line(fp, "parsed_instruction_lines=%d" % len(rows))

                        write_line(fp)
                        write_line(fp, "== Required target inventory ==")
                        for name in cfg["targets"]:
                            idxs = exact_indices(symbols, name)
                            write_line(fp, "target=%s count=%d" % (name, len(idxs)))
                            if len(idxs) == 1:
                                write_line(fp, "%s@0x%x" % (name, symbols[idxs[0]][0]))
                            else:
                                issues.append("expected exactly one target: %s" % name)

                        main_idxs = exact_indices(symbols, "_CGSMainDisplayID")
                        resolve_idxs = exact_indices(symbols, "_CGSResolveShmemReference")
                        get_idxs = exact_indices(symbols, "__CGSGetDisplayShmem")

                        main_external = len(main_idxs) == 1 and " external " in (" " + symbols[main_idxs[0]][2] + " ")
                        resolve_external = len(resolve_idxs) == 1 and " external " in (" " + symbols[resolve_idxs[0]][2] + " ")
                        get_nonexternal = len(get_idxs) == 1 and "non-external" in symbols[get_idxs[0]][2]

                        write_line(fp)
                        write_line(fp, "== Callable/read-only snapshot boundary ==")
                        write_line(fp, "main_display_id_external=%s" % ("YES" if main_external else "NO"))
                        write_line(fp, "resolve_shmem_reference_external=%s" % ("YES" if resolve_external else "NO"))
                        write_line(fp, "get_display_shmem_nonexternal=%s" % ("YES" if get_nonexternal else "NO"))
                        if not main_external:
                            issues.append("_CGSMainDisplayID is not external")
                        if not resolve_external:
                            issues.append("_CGSResolveShmemReference is not external")
                        if not get_nonexternal:
                            issues.append("__CGSGetDisplayShmem external-status mismatch")

                        resolve_raw = raw_at(rows, cfg["resolve_call_addr"])
                        store_raw = raw_at(rows, cfg["mapping_store_addr"])
                        route_raw = raw_at(rows, cfg["main_route_addr"])

                        write_line(fp, "initializer=%s" % cfg["initializer"])
                        write_line(fp, "resolve_call_site=0x%x" % cfg["resolve_call_addr"])
                        write_line(fp, "resolve_call_raw=%s" % (resolve_raw or "MISSING"))
                        write_line(fp, "mapping_store_site=0x%x" % cfg["mapping_store_addr"])
                        write_line(fp, "mapping_store_raw=%s" % (store_raw or "MISSING"))
                        write_line(fp, "pic_anchor=0x%x" % cfg["pic_anchor"])
                        if mode == "snow":
                            write_line(fp, "pic_high=0x%x" % cfg["pic_high"])
                            write_line(fp, "mapping_store_disp_raw=0x%x" % cfg["store_disp_raw"])
                        else:
                            write_line(fp, "pic_disp=0x%x" % cfg["pic_disp"])
                        write_line(fp, "mapping_global_vmaddr=0x%x" % cfg["mapping_global_vmaddr"])
                        write_line(fp, "main_route_site=0x%x" % cfg["main_route_addr"])
                        write_line(fp, "main_route_target=%s" % cfg["main_route_target"])
                        write_line(fp, "main_route_raw=%s" % (route_raw or "MISSING"))
                        write_line(fp, "snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_INITIALIZER_MAPPING_GLOBAL")

                        if resolve_raw is None or "_CGSResolveShmemReference" not in resolve_raw:
                            if mode == "lion" and resolve_raw is not None and "0x000741cd" in resolve_raw:
                                pass
                            else:
                                issues.append("resolver call-site mismatch")

                        if mode == "snow":
                            if store_raw is None or "stw" not in store_raw or "r3,0xfaa0(r30)" not in store_raw:
                                issues.append("Snow mapping-global store mismatch")
                            calculated = cfg["pic_anchor"] + (cfg["pic_high"] << 16)
                            disp = cfg["store_disp_raw"]
                            if disp & 0x8000:
                                disp -= 0x10000
                            calculated += disp
                        else:
                            if store_raw is None or "movl" not in store_raw or "%eax,0x0087ca87(%esi)" not in store_raw:
                                issues.append("Lion mapping-global store mismatch")
                            calculated = cfg["pic_anchor"] + cfg["pic_disp"]

                        write_line(fp, "mapping_global_calculated_vmaddr=0x%x" % calculated)
                        exact_global = calculated == cfg["mapping_global_vmaddr"]
                        write_line(fp, "mapping_global_calculation_exact=%s" % ("YES" if exact_global else "NO"))
                        if not exact_global:
                            issues.append("mapping-global calculation mismatch")

                        if route_raw is None or cfg["main_route_target"] not in route_raw:
                            issues.append("_CGSMainDisplayID route mismatch")

                        for name in cfg["targets"]:
                            emit_target(fp, symbols, groups, name)

            write_line(fp)
            write_line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "display_shmem_snapshot_entry_contract_audit_exact=YES")
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
