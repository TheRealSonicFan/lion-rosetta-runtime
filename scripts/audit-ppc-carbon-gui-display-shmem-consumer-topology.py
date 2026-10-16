#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "2"
AUDIT_CONTRACT = "carbon-gui-display-shmem-consumer-topology-v2"

COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

CONFIG = {
    "snow": {
        "product": "10.6.8",
        "build": "10K549",
        "arch": "ppc7400",
        "slice_sha256": "83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a",
        "globals": {
            "selector": (0x6ff26c, 4),
            "source_array": (0x700460, 8),
            "local_array": (0x700458, 8),
            "mode2": (0x70046c, 4),
        },
        "required_xrefs": {
            "selector": ["_lookupMainDisplay"],
            "source_array": ["_lookupMainDisplay", "_initCGDisplayMappings"],
            "local_array": ["_lookupMainDisplay", "_initCGDisplayMappings"],
        },
        "required_targets": [
            "_CGSMainDisplayID",
            "_lookupMainDisplay",
            "_initCGDisplayMappings",
            "_initCGDisplayState",
            "_bindDisplayMapping",
            "_updateAllDisplayInfoAsNeeded",
            "_CGSDisplayChangedSeed",
            "_CGSDisplayMappingChangedSeed",
            "_CGSDisplayNotifyProc",
        ],
        "display_notify_target": "_CGSDisplayNotifyProc",
    },
    "lion": {
        "product": "10.7.5",
        "build": "11G63",
        "arch": "i386",
        "slice_sha256": "4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d",
        "globals": {
            "selector": (0x948630, 4),
            "source_array": (0x94983c, 8),
            "local_array": (0x94984c, 8),
            "mode2": (0x949848, 4),
        },
        "required_xrefs": {
            "selector": ["_lookupMainDisplay"],
            "source_array": ["_lookupMainDisplay", "_initDisplayMappings"],
            "local_array": ["_lookupMainDisplay", "_initDisplayMappings"],
        },
        "required_targets": [
            "_CGSMainDisplayID",
            "_lookupDisplayNumber",
            "_lookupMainDisplay",
            "_initDisplayMappings",
            "_initDisplayState",
            "_updateAllDisplayInfoAsNeeded",
            "_CGSDisplayChangedSeed",
            "_CGSDisplayMappingChangedSeed",
            "__CGSDisplayNotifyProc",
        ],
        "display_notify_target": "__CGSDisplayNotifyProc",
    },
}

HEX_TOKEN = re.compile(r"0x([0-9a-fA-F]+)")
PPC_REG = re.compile(r"^r([0-9]+)$")
I386_REG = re.compile(r"^%(e(?:ax|bx|cx|dx|si|di))$")
I386_EBP_MEM = re.compile(r"^(-?0x[0-9a-fA-F]+|[0-9]+)\(%ebp\)$")
I386_MEM = re.compile(
    r"^(-?0x[0-9a-fA-F]+|[0-9]+)?\(%(e(?:ax|bx|cx|dx|si|di))(?:,%e(?:ax|bx|cx|dx|si|di),[1248])?\)$"
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
    token = token.strip().rstrip(":")
    if token.startswith("0x") or token.startswith("0X"):
        token = token[2:]
    if not token:
        return None
    try:
        return int(token, 16)
    except ValueError:
        return None

def parse_signed(token, bits):
    token = token.strip()
    neg = token.startswith("-")
    if neg:
        token = token[1:]
    if token.startswith("0x") or token.startswith("0X"):
        value = int(token[2:], 16)
    else:
        value = int(token, 10)
    if neg:
        return -value
    sign = 1 << (bits - 1)
    mask = (1 << bits) - 1
    value &= mask
    return value - (1 << bits) if value & sign else value

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
        addr = parse_hex(parts[0])
        if addr is None:
            continue
        result.append((addr, parts[-1], raw))
    result.sort()
    return result

def parse_rows(text):
    rows = []
    for raw in text.splitlines():
        m = re.match(r"^\s*([0-9a-fA-F]+)\s+([^\s]+)(?:\s+(.*))?$", raw)
        if not m:
            continue
        addr = int(m.group(1), 16)
        op = m.group(2)
        operands = (m.group(3) or "").split(";", 1)[0].strip()
        rows.append((addr, op, operands, raw))
    return rows

def group_rows(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for row in rows:
        addr = row[0]
        while si + 1 < len(symbols) and symbols[si + 1][0] <= addr:
            si += 1
        if symbols[si][0] <= addr:
            groups.setdefault(si, []).append(row)
    return groups

def exact_indices(symbols, name):
    return [i for i, item in enumerate(symbols) if item[1] == name]

def classify_target(cfg, address):
    for name, pair in cfg["globals"].items():
        base, size = pair
        if base <= address < base + size:
            return name, address - base
    return None, None

def split_operands(operands):
    return [x.strip() for x in operands.split(",") if x.strip()]

def ppc_reg(token):
    m = PPC_REG.match(token)
    return int(m.group(1)) if m else None

def ppc_xrefs(selected, cfg):
    regs = {}
    pending_lr = None
    hits = []

    no_gpr_write_prefixes = (
        "b", "cmp", "cmpl", "st", "mt", "sync", "isync", "eieio", "nop"
    )

    for addr, op, operands, raw in selected:
        args = split_operands(operands)

        if op == "bcl":
            values = HEX_TOKEN.findall(operands)
            if values:
                pending_lr = int(values[-1], 16)
            continue

        if op == "mfspr" and len(args) >= 2 and args[1] == "lr":
            rd = ppc_reg(args[0])
            if rd is not None:
                if pending_lr is not None:
                    regs[rd] = pending_lr
                else:
                    regs.pop(rd, None)
            continue

        # Record direct displacement references before applying destination
        # register effects.  Only a register still carrying a proven PIC
        # constant may contribute a global reference.
        m = re.search(r"(-?0x[0-9a-fA-F]+|[0-9]+)\(r([0-9]+)\)", operands)
        if m:
            base_reg = int(m.group(2))
            if base_reg in regs:
                try:
                    target = regs[base_reg] + parse_signed(m.group(1), 16)
                    label, slot = classify_target(cfg, target)
                    if label is not None:
                        hits.append((label, slot, addr, raw))
                except Exception:
                    pass

        if op == "addis" and len(args) >= 3:
            rd = ppc_reg(args[0])
            ra = ppc_reg(args[1])
            if rd is not None:
                if ra in regs:
                    try:
                        regs[rd] = regs[ra] + (parse_signed(args[2], 16) << 16)
                    except Exception:
                        regs.pop(rd, None)
                else:
                    regs.pop(rd, None)
            continue

        if op == "addi" and len(args) >= 3:
            rd = ppc_reg(args[0])
            ra = ppc_reg(args[1])
            if rd is not None:
                if ra in regs:
                    try:
                        target = regs[ra] + parse_signed(args[2], 16)
                        regs[rd] = target
                        label, slot = classify_target(cfg, target)
                        if label is not None:
                            hits.append((label, slot, addr, raw))
                    except Exception:
                        regs.pop(rd, None)
                else:
                    regs.pop(rd, None)
            continue

        if op == "or" and len(args) >= 3:
            rd = ppc_reg(args[0])
            rs1 = ppc_reg(args[1])
            rs2 = ppc_reg(args[2])
            if rd is not None:
                if rs1 == rs2 and rs1 in regs:
                    regs[rd] = regs[rs1]
                else:
                    regs.pop(rd, None)
            continue

        if op == "lmw" and args:
            rd = ppc_reg(args[0])
            if rd is not None:
                for reg in list(regs.keys()):
                    if reg >= rd:
                        regs.pop(reg, None)
            continue

        if op in ("bl", "bla", "bctrl", "blrl"):
            # Darwin PPC calls may clobber volatile GPRs.  Keep only
            # callee-saved PIC bases so stale object values cannot masquerade
            # as later shared-state globals.
            for reg in list(regs.keys()):
                if reg <= 12:
                    regs.pop(reg, None)
            continue

        # Conservative invalidation: for ordinary PPC instructions the first
        # GPR operand is the destination.  Stores, compares, branches, and
        # special-register writes are excluded above/by prefix.
        if args and not op.startswith(no_gpr_write_prefixes):
            rd = ppc_reg(args[0])
            if rd is not None:
                regs.pop(rd, None)

    return hits

def i386_reg(token):
    m = I386_REG.match(token)
    return m.group(1) if m else None

def i386_parent_reg(token):
    token = token.strip()
    groups = {
        "%eax": "eax", "%ax": "eax", "%al": "eax", "%ah": "eax",
        "%ebx": "ebx", "%bx": "ebx", "%bl": "ebx", "%bh": "ebx",
        "%ecx": "ecx", "%cx": "ecx", "%cl": "ecx", "%ch": "ecx",
        "%edx": "edx", "%dx": "edx", "%dl": "edx", "%dh": "edx",
        "%esi": "esi", "%si": "esi",
        "%edi": "edi", "%di": "edi",
    }
    return groups.get(token)

def i386_disp(token):
    if token is None or token == "":
        return 0
    return parse_signed(token, 32)

def i386_memory_parts(token):
    m = re.match(
        r"^(-?0x[0-9a-fA-F]+|[0-9]+)?\(%(e(?:ax|bx|cx|dx|si|di))"
        r"(?:,%(e(?:ax|bx|cx|dx|si|di)),([1248]))?\)$",
        token)
    if not m:
        return None
    return (i386_disp(m.group(1)), m.group(2), m.group(3),
            int(m.group(4)) if m.group(4) else None)

def i386_xrefs(selected, cfg):
    regs = {}
    stack = {}
    hits = []
    pic_call_target = None

    no_register_write_prefixes = (
        "j", "call", "ret", "cmp", "test", "push", "nop"
    )

    for addr, op, operands, raw in selected:
        args = split_operands(operands)

        # Record every memory operand whose base still carries a proven PIC
        # constant.  Indexed references classify the array base, not a guessed
        # runtime element.
        for token in args:
            parts = i386_memory_parts(token)
            if parts is None:
                continue
            disp, base, index, scale = parts
            if base in regs:
                target = regs[base] + disp
                label, slot = classify_target(cfg, target)
                if label is not None:
                    hits.append((label, slot, addr, raw))

        if op == "calll":
            values = HEX_TOKEN.findall(operands)
            target = int(values[-1], 16) if values else None
            pic_call_target = target
            if target != addr + 5:
                for reg in ("eax", "ecx", "edx"):
                    regs.pop(reg, None)
            continue

        if op == "popl" and len(args) == 1:
            rd = i386_parent_reg(args[0])
            if rd is not None:
                if pic_call_target == addr:
                    regs[rd] = addr
                else:
                    regs.pop(rd, None)
            pic_call_target = None
            continue

        pic_call_target = None

        if op in ("movl", "leal") and len(args) == 2:
            src, dst = args
            rd = i386_parent_reg(dst)
            dst_stack = I386_EBP_MEM.match(dst)

            if op == "leal" and rd is not None:
                parts = i386_memory_parts(src)
                if parts is not None:
                    disp, base, index, scale = parts
                    if base in regs and index is None:
                        regs[rd] = regs[base] + disp
                        label, slot = classify_target(cfg, regs[rd])
                        if label is not None:
                            hits.append((label, slot, addr, raw))
                    else:
                        regs.pop(rd, None)
                else:
                    regs.pop(rd, None)
            elif rd is not None:
                rs = i386_parent_reg(src)
                src_stack = I386_EBP_MEM.match(src)
                if rs is not None and rs in regs:
                    regs[rd] = regs[rs]
                elif src_stack:
                    key = i386_disp(src_stack.group(1))
                    if key in stack:
                        regs[rd] = stack[key]
                    else:
                        regs.pop(rd, None)
                else:
                    regs.pop(rd, None)

            if dst_stack:
                key = i386_disp(dst_stack.group(1))
                rs = i386_parent_reg(src)
                if op == "movl" and rs is not None and rs in regs:
                    stack[key] = regs[rs]
                else:
                    stack.pop(key, None)
            continue

        if op in ("addl", "subl") and len(args) == 2 and args[0].startswith("$"):
            rd = i386_parent_reg(args[1])
            if rd is not None:
                if rd in regs:
                    try:
                        delta = parse_signed(args[0][1:], 32)
                        regs[rd] = regs[rd] + delta if op == "addl" else regs[rd] - delta
                    except Exception:
                        regs.pop(rd, None)
                else:
                    regs.pop(rd, None)
            continue

        if op == "leave":
            stack.clear()
            continue

        # Conservative destination invalidation catches movzbl/xorl/imull/
        # shifts/increments/etc. that previously left stale PIC constants in
        # registers and created false shared-global xrefs.
        if args and not op.startswith(no_register_write_prefixes):
            rd = i386_parent_reg(args[-1])
            if rd is not None:
                regs.pop(rd, None)

    return hits

def direct_symbol_refs(symbols, groups, target_name):
    idxs = exact_indices(symbols, target_name)
    if len(idxs) != 1:
        return []
    target_addr = symbols[idxs[0]][0]
    forms = ["0x%x" % target_addr, "0x%08x" % target_addr, target_name.lower()]
    refs = []
    branch_ops = ("bl", "b", "calll", "jmp")
    for idx, selected in groups.items():
        if idx == idxs[0]:
            continue
        for addr, op, operands, raw in selected:
            if op not in branch_ops:
                continue
            low = raw.lower()
            if any(form.lower() in low for form in forms):
                refs.append((symbols[idx][1], symbols[idx][0], addr, raw))
    return refs

def emit_target_body(fp, symbols, groups, name):
    idxs = exact_indices(symbols, name)
    line(fp)
    line(fp, "== Target: %s ==" % name)
    line(fp, "target_count=%d" % len(idxs))
    if len(idxs) != 1:
        return
    idx = idxs[0]
    line(fp, "symbol_address=0x%x" % symbols[idx][0])
    selected = groups.get(idx, [])
    line(fp, "instruction_lines=%d" % len(selected))
    for row in selected:
        line(fp, row[3])

def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-consumer-topology.")

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
            line(fp, "== PPC Carbon GUI display-shmem consumer-topology audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % (mode or "unsupported"))
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "live_snapshot_result=LAYOUT_MISMATCH_CAUSAL")
            line(fp, "shared_record_rewrite_authorized=NO")
            line(fp, "process_local_projection_implementation_authorized=NO")
            line(fp, "display_id_substitution_authorized=NO")
            line(fp, "display_id_normalization_authorized=NO")
            line(fp, "private_hitoolbox_patch_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            if mode is None:
                issues.append("unsupported product/build")
            else:
                cfg = CONFIG[mode]
                line(fp, "required_arch=%s" % cfg["arch"])
                line(fp, "expected_slice_sha256=%s" % cfg["slice_sha256"])

                if not os.path.isfile(COREGRAPHICS):
                    issues.append("CoreGraphics missing")
                else:
                    dst = os.path.join(tempdir, "CoreGraphics." + cfg["arch"])
                    ok, out = thin(COREGRAPHICS, cfg["arch"], dst)
                    line(fp, "thin=%s" % ("YES" if ok else "NO"))
                    if not ok:
                        line(fp, out.rstrip())
                        issues.append("required CoreGraphics slice missing")
                    else:
                        actual = sha256(dst)
                        line(fp, "slice_sha256=%s" % actual)
                        exact = actual == cfg["slice_sha256"]
                        line(fp, "slice_exact=%s" % ("YES" if exact else "NO"))
                        if not exact:
                            issues.append("CoreGraphics slice SHA-256 mismatch")

                        rc, nm_out = run(["/usr/bin/nm", "-nm", dst])
                        symbols = parse_symbols(nm_out) if rc == 0 else []
                        if rc != 0:
                            issues.append("nm failed")

                        rc, dis_out = run(["/usr/bin/otool", "-tvV", dst])
                        rows = parse_rows(dis_out) if rc == 0 else []
                        groups = group_rows(rows, symbols) if rc == 0 else {}
                        if rc != 0:
                            issues.append("otool disassembly failed")

                        line(fp)
                        line(fp, "== Standalone shared-state globals ==")
                        for name in ("selector", "source_array", "local_array", "mode2"):
                            base, size = cfg["globals"][name]
                            line(fp, "%s_vmaddr=0x%x size=0x%x" %
                                 (name, base, size))

                        line(fp)
                        line(fp, "== Required target inventory ==")
                        for name in cfg["required_targets"]:
                            count = len(exact_indices(symbols, name))
                            line(fp, "target=%s count=%d" % (name, count))
                            if count != 1:
                                issues.append("expected exactly one target: %s" % name)

                        all_hits = []
                        for idx, selected in groups.items():
                            if mode == "snow":
                                hits = ppc_xrefs(selected, cfg)
                            else:
                                hits = i386_xrefs(selected, cfg)
                            for label, slot, addr, raw in hits:
                                all_hits.append((label, slot, idx, addr, raw))

                        line(fp)
                        line(fp, "== Exact global-reference topology ==")
                        for label in ("selector", "source_array", "local_array", "mode2"):
                            selected_hits = [h for h in all_hits if h[0] == label]
                            callers = []
                            line(fp, "%s_xref_count=%d" % (label, len(selected_hits)))
                            for h in selected_hits:
                                caller = symbols[h[2]][1]
                                if caller not in callers:
                                    callers.append(caller)
                                line(fp,
                                     "%s_xref caller=%s@0x%x site=0x%x slot=0x%x raw=%s" %
                                     (label, caller, symbols[h[2]][0], h[3], h[1], h[4]))
                            line(fp, "%s_unique_caller_count=%d" %
                                 (label, len(callers)))
                            line(fp, "%s_unique_callers=%s" %
                                 (label, ",".join(callers) if callers else "NONE"))

                            for required in cfg["required_xrefs"].get(label, []):
                                present = required in callers
                                line(fp, "%s_required_caller_%s=%s" %
                                     (label, required,
                                      "YES" if present else "NO"))
                                if not present:
                                    issues.append("%s missing required caller %s" %
                                                  (label, required))

                        line(fp)
                        line(fp, "== Lifecycle direct-reference topology ==")
                        lifecycle = [
                            "_initCGDisplayMappings" if mode == "snow" else "_initDisplayMappings",
                            "_initCGDisplayState" if mode == "snow" else "_initDisplayState",
                            "_updateAllDisplayInfoAsNeeded",
                            "_CGSDisplayChangedSeed",
                            "_CGSDisplayMappingChangedSeed",
                            cfg["display_notify_target"],
                        ]
                        for name in lifecycle:
                            refs = direct_symbol_refs(symbols, groups, name)
                            line(fp, "%s_direct_reference_count=%d" %
                                 (name, len(refs)))
                            for caller, caller_addr, site, raw in refs:
                                line(fp,
                                     "%s_ref caller=%s@0x%x site=0x%x raw=%s" %
                                     (name, caller, caller_addr, site, raw))

                        for name in cfg["required_targets"]:
                            emit_target_body(fp, symbols, groups, name)

            line(fp)
            line(fp, "== Projection-boundary questions ==")
            line(fp, "question_1=Which exact Snow functions read the selector, source-array, and local-array globals after initialization?")
            line(fp, "question_2=Which exact Snow function first stores the mode-1 resolved source mappings into the source-array slots?")
            line(fp, "question_3=Which functions invalidate, rebuild, or reseed those source/local mappings after WindowServer display changes?")
            line(fp, "question_4=Can a process-local Snow-layout projection be substituted at one source-array ownership point without mutating the server-owned Lion mapping?")
            line(fp, "question_5=Would such a projection also require rebuilding the release-local local-mapping array, or can _initCGDisplayMappings bind it normally from projected source records?")
            line(fp, "question_6=What lifecycle event must refresh a projection so it cannot become stale after display-change or mapping-change seeds advance?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_consumer_topology_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No display/CGS/WindowServer request was issued.")
            line(fp, "CoreGraphics was read only.")
            line(fp, "Temporary architecture slices were removed on exit.")
            line(fp, "No shared memory, CoreGraphics, Rosetta cache, dyld, WindowServer, or XNU state was modified.")

        print("Created: %s" % output)
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
