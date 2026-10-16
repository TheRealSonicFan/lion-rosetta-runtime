#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-display-shmem-semantic-fields-v1"

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

TARGETS = {
    "snow": [
        "_initCGDisplayMappings",
        "_bindDisplayMapping",
        "_lookupMainDisplay",
        "_lookupDisplay",
        "_CGSMainDisplayID",
        "__XGetDisplayShmem",
        "__CGXGetDisplayShmem",
    ],
    "lion": [
        "_initDisplayMappings",
        "_lookupMainDisplay",
        "_lookupDisplay",
        "_lookupDisplayNumber",
        "_CGSMainDisplayID",
        "__XGetDisplayShmem",
        "__CGXGetDisplayShmem",
    ],
}

MAIN_LOOKUP_FIELDS = {
    "snow": [0x0f4, 0x0f8, 0x10c, 0x10d, 0x10e, 0x110, 0x111, 0x112, 0x113],
    "lion": [0x110, 0x114, 0x128, 0x129, 0x12a, 0x12c, 0x12d, 0x12e, 0x12f],
}

SUPPORT_FIELDS = {
    "snow": [0x12d, 0x13c],
    "lion": [0x118, 0x138, 0x154, 0x170],
}

DISPLAY_SYMBOL_RE = re.compile(r"(display|screen|monitor|dspy|cgx)", re.I)
HEX_RE = re.compile(r"0x([0-9a-fA-F]+)")
CALL_RE = re.compile(r"\b(bl|b|calll|callq|jmp)\b", re.I)


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


def row_values(raw):
    values = []
    for token in HEX_RE.findall(raw):
        try:
            values.append(int(token, 16))
        except ValueError:
            pass
    return values


def emit_symbol(fp, symbols, groups, idx):
    addr, name, raw = symbols[idx]
    selected = groups.get(idx, [])
    calls = [r for a, r in selected if CALL_RE.search(r)]

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


def emit_field_reference_inventory(fp, mode, symbols, groups):
    fields = sorted(set(MAIN_LOOKUP_FIELDS[mode] + SUPPORT_FIELDS[mode]))
    line(fp)
    line(fp, "== Display semantic-field reference inventory ==")
    for field in fields:
        refs = []
        for idx, selected in groups.items():
            name = symbols[idx][1]
            if not DISPLAY_SYMBOL_RE.search(name):
                continue
            for addr, raw in selected:
                if field in row_values(raw):
                    refs.append((name, symbols[idx][0], addr, raw))
        line(fp, "field_0x%03x_reference_count=%d" % (field, len(refs)))
        for name, sym_addr, addr, raw in refs[:250]:
            line(fp, "field_0x%03x_ref symbol=%s@0x%x instruction=0x%x raw=%s" %
                 (field, name, sym_addr, addr, raw))


def target_has_field(symbols, groups, target_name, value):
    idxs = exact_indices(symbols, target_name)
    if len(idxs) != 1:
        return False
    for addr, raw in groups.get(idxs[0], []):
        if value in row_values(raw):
            return True
    return False


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    report = sys.argv[1]
    issues = []
    tempdir = tempfile.mkdtemp(prefix="ppc-carbon-display-shmem-fields.")

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
            line(fp, "== PPC Carbon GUI display-shmem semantic-field audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % mode)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % (arch or "UNSUPPORTED"))
            line(fp, "prior_wire_relation=IDENTICAL")
            line(fp, "prior_source_record_stride_snow=0x150")
            line(fp, "prior_source_record_stride_lion=0x17c")
            line(fp, "candidate_main_semantic_shift=0x1c")
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

                    line(fp)
                    line(fp, "== Required target inventory ==")
                    for name in TARGETS[mode]:
                        idxs = exact_indices(symbols, name)
                        line(fp, "target=%s count=%d" % (name, len(idxs)))
                        for idx in idxs:
                            line(fp, "%s@0x%x" %
                                 (symbols[idx][1], symbols[idx][0]))
                        if len(idxs) != 1:
                            issues.append("expected exactly one target: %s" % name)

                    for name in TARGETS[mode]:
                        for idx in exact_indices(symbols, name):
                            emit_symbol(fp, symbols, groups, idx)

                    emit_field_reference_inventory(fp, mode, symbols, groups)

                    line(fp)
                    line(fp, "== Main-display semantic-field discriminator ==")
                    for field in MAIN_LOOKUP_FIELDS[mode]:
                        present = target_has_field(
                            symbols, groups, "_lookupMainDisplay", field)
                        line(fp, "lookup_main_field_0x%03x=%s" %
                             (field, "YES" if present else "NO"))
                        if not present:
                            issues.append("_lookupMainDisplay missing field 0x%x" % field)

                    if mode == "snow":
                        line(fp, "main_id_field_primary=0x0f4")
                        line(fp, "main_id_field_secondary=0x0f8")
                        line(fp, "main_status_block=0x10c-0x113")
                    else:
                        line(fp, "main_id_field_primary=0x110")
                        line(fp, "main_id_field_secondary=0x114")
                        line(fp, "main_status_block=0x128-0x12f")

            line(fp)
            line(fp, "== Cross-release correspondence to verify ==")
            line(fp, "pair=0x0f4->0x110 delta=0x1c")
            line(fp, "pair=0x0f8->0x114 delta=0x1c")
            line(fp, "pair=0x10c->0x128 delta=0x1c")
            line(fp, "pair=0x10d->0x129 delta=0x1c")
            line(fp, "pair=0x10e->0x12a delta=0x1c")
            line(fp, "pair=0x110->0x12c delta=0x1c")
            line(fp, "pair=0x111->0x12d delta=0x1c")
            line(fp, "pair=0x112->0x12e delta=0x1c")
            line(fp, "pair=0x113->0x12f delta=0x1c")
            line(fp, "unresolved_lion_fields=0x118,0x138,0x154,0x170")
            line(fp, "unresolved_record_growth=0x2c")

            line(fp)
            line(fp, "== Comparison questions ==")
            line(fp, "question_1=Do the main-display identity and status fields form an exact +0x1c semantic shift from Snow to Lion?")
            line(fp, "question_2=Which display-related functions write or read each field in the two layouts?")
            line(fp, "question_3=What does Snow __CGXGetDisplayShmem return for all three reference pairs, and how does that compare with Lion?")
            line(fp, "question_4=What semantic roles do Lion fields 0x118,0x138,0x154,0x170 have, and which Snow fields correspond if any?")
            line(fp, "question_5=Where is the remaining 0x10 of Lion's total +0x2c record growth located relative to the +0x1c shifted semantic block?")
            line(fp, "question_6=Does this evidence justify a passive mapped-state snapshot next, or is another writer-side static boundary required first?")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "display_shmem_semantic_field_audit_exact=YES")
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
