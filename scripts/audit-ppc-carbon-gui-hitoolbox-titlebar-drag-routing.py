#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-hitoolbox-titlebar-drag-routing-v1"

HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_PRODUCT = "10.6.8"
EXPECTED_BUILD = "10K549"
EXPECTED_ARCH = "ppc7400"
EXPECTED_HITOOLBOX_SHA = "fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f"
EXPECTED_CACHE_SHA = "2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_MAP_SHA = "66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"

FOCUS = [
    "_DragWindow",
    "_FindWindow",
    "_GetThemeWindowRegionHit",
    "_HIThemeGetWindowRegionHit",
    "__ZN14ThemeWindowDef7HitSelfE5Point",
]

TRACKER_PATTERNS = (
    "TWindowTracker",
    "TDragTracker",
)

CANDIDATE_RE = re.compile(
    r"(Drag|Track|HitSelf|Window.*Event|Event.*Window|Mouse|Standard.*Handler|Window.*Handler)",
    re.I,
)

CALL_MNEMONICS = set(["bl", "bla", "call", "calll"])


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha256(path):
    h = hashlib.sha256()
    fp = open(path, "rb")
    try:
        while True:
            block = fp.read(1024 * 1024)
            if not block:
                break
            h.update(block)
    finally:
        fp.close()
    return h.hexdigest()


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def parse_hex(token):
    token = token.rstrip(":")
    if token.startswith("0x") or token.startswith("0X"):
        token = token[2:]
    if not token:
        return None
    try:
        return int(token, 16)
    except ValueError:
        return None


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True
    rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0


def thin(src, arch, dst):
    if not verify_arch(src, arch):
        return False
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0


def parse_symbols(text):
    ordered = []
    by_name = {}
    by_addr = {}
    for raw in text.splitlines():
        parts = raw.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in raw:
            continue
        addr = parse_hex(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        if name not in by_name:
            by_name[name] = addr
        if addr not in by_addr:
            by_addr[addr] = name
    ordered.sort()
    return ordered, by_name, by_addr


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


def containing_symbol(symbols, addr):
    lo = 0
    hi = len(symbols)
    while lo < hi:
        mid = (lo + hi) // 2
        if symbols[mid][0] <= addr:
            lo = mid + 1
        else:
            hi = mid
    idx = lo - 1
    if idx < 0:
        return None, None
    return symbols[idx]


def body_for(symbols, rows, by_name, name):
    start = by_name.get(name)
    if start is None:
        return None, []
    idx = None
    for i, item in enumerate(symbols):
        if item[0] == start and item[1] == name:
            idx = i
            break
    if idx is None:
        return start, []
    end = symbols[idx + 1][0] if idx + 1 < len(symbols) else None
    return start, [(addr, raw) for addr, raw in rows
                   if addr >= start and (end is None or addr < end)]


def parse_call(raw):
    fields = raw.split("\t")
    if len(fields) < 3:
        return None, None
    mnemonic = fields[1].strip().split()[0] if fields[1].strip() else ""
    if mnemonic not in CALL_MNEMONICS:
        return None, None
    operand = fields[2].strip().split()[0] if fields[2].strip() else ""
    if not operand:
        return mnemonic, None
    return mnemonic, operand


def direct_callers(symbols, rows, by_name, target_name):
    target_addr = by_name.get(target_name)
    if target_addr is None:
        return []
    found = []
    seen = set()
    for addr, raw in rows:
        mnemonic, operand = parse_call(raw)
        if mnemonic is None or operand is None:
            continue
        hit = False
        if operand == target_name:
            hit = True
        else:
            numeric = parse_hex(operand)
            if numeric is not None and numeric == target_addr:
                hit = True
        if not hit:
            continue
        caller_addr, caller_name = containing_symbol(symbols, addr)
        key = (caller_addr, caller_name, addr)
        if key in seen:
            continue
        seen.add(key)
        found.append((caller_addr, caller_name, addr, raw))
    return found


def body_contains(body, fragment):
    return any(fragment in raw for addr, raw in body)


def emit_body(fp, name, addr, body):
    line(fp)
    line(fp, "== focus symbol ==")
    line(fp, "name=%s" % name)
    line(fp, "present=%s" % ("YES" if addr is not None else "NO"))
    if addr is None:
        return
    line(fp, "address=0x%08x" % addr)
    line(fp, "instruction_lines=%d" % len(body))
    for row_addr, raw in body:
        line(fp, raw)


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-titlebar-drag-routing.")

    try:
        rc, product = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product.strip() if rc == 0 else "UNKNOWN"
        rc, build = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build.strip() if rc == 0 else "UNKNOWN"

        if product != EXPECTED_PRODUCT:
            issues.append("unexpected product version")
        if build != EXPECTED_BUILD:
            issues.append("unexpected build version")

        cache_sha = sha256(ROSETTA_CACHE) if os.path.isfile(ROSETTA_CACHE) else "MISSING"
        map_sha = sha256(ROSETTA_MAP) if os.path.isfile(ROSETTA_MAP) else "MISSING"
        if cache_sha != EXPECTED_CACHE_SHA:
            issues.append("Rosetta cache SHA mismatch")
        if map_sha != EXPECTED_MAP_SHA:
            issues.append("Rosetta map SHA mismatch")

        thin_path = os.path.join(tmpdir, "HIToolbox.ppc7400")
        hit_sha = "MISSING"
        symbols = []
        by_name = {}
        by_addr = {}
        rows = []

        if not os.path.isfile(HITOOLBOX):
            issues.append("HIToolbox missing")
        elif not thin(HITOOLBOX, EXPECTED_ARCH, thin_path):
            issues.append("PPC7400 HIToolbox slice unavailable")
        else:
            hit_sha = sha256(thin_path)
            if hit_sha != EXPECTED_HITOOLBOX_SHA:
                issues.append("HIToolbox SHA mismatch")
            rc, nm = run(["/usr/bin/nm", "-nm", thin_path])
            if rc != 0:
                issues.append("nm failed")
            else:
                symbols, by_name, by_addr = parse_symbols(nm)
            rc, dis = run(["/usr/bin/otool", "-tvV", thin_path])
            if rc != 0:
                issues.append("otool disassembly failed")
            else:
                rows = parse_rows(dis)

        for name in FOCUS:
            if name not in by_name:
                issues.append("required symbol missing: %s" % name)

        tracker_names = [
            name for addr, name in symbols
            if any(pattern in name for pattern in TRACKER_PATTERNS)
        ]
        candidate_names = [
            name for addr, name in symbols
            if CANDIDATE_RE.search(name)
        ]

        drag_addr, drag_body = body_for(symbols, rows, by_name, "_DragWindow")
        hit_addr, hit_body = body_for(symbols, rows, by_name, "__ZN14ThemeWindowDef7HitSelfE5Point")
        region_addr, region_body = body_for(symbols, rows, by_name, "_GetThemeWindowRegionHit")

        if drag_body and not body_contains(drag_body, "TWindowTracker"):
            issues.append("DragWindow no longer names TWindowTracker")
        if hit_body and not body_contains(hit_body, "_GetThemeWindowRegionHit"):
            issues.append("HitSelf no longer reaches GetThemeWindowRegionHit")
        if region_body and not body_contains(region_body, "_HIThemeGetWindowRegionHit"):
            issues.append("GetThemeWindowRegionHit no longer reaches HIThemeGetWindowRegionHit")

        with open(output, "w") as fp:
            line(fp, "== PPC Carbon GUI HIToolbox titlebar drag-routing audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % EXPECTED_ARCH)
            line(fp, "runtime_on_lion_contract=accepted_identical_snow_ppc_cache")

            line(fp)
            line(fp, "== Provenance ==")
            line(fp, "hitoolbox_slice_sha256=%s" % hit_sha)
            line(fp, "hitoolbox_slice_exact=%s" % ("YES" if hit_sha == EXPECTED_HITOOLBOX_SHA else "NO"))
            line(fp, "rosetta_cache_sha256=%s" % cache_sha)
            line(fp, "rosetta_cache_map_sha256=%s" % map_sha)

            line(fp)
            line(fp, "== Direct caller inventory ==")
            targets = list(FOCUS) + tracker_names
            emitted = set()
            for name in targets:
                if name in emitted:
                    continue
                emitted.add(name)
                callers = direct_callers(symbols, rows, by_name, name)
                line(fp, "target=%s address=%s direct_callers=%d" % (
                    name,
                    "0x%08x" % by_name[name] if name in by_name else "MISSING",
                    len(callers)
                ))
                for caller_addr, caller_name, call_addr, raw in callers:
                    line(fp, "caller target=%s caller=%s caller_start=%s call_site=0x%08x raw=%s" % (
                        name,
                        caller_name or "UNRESOLVED",
                        "0x%08x" % caller_addr if caller_addr is not None else "UNRESOLVED",
                        call_addr,
                        raw
                    ))

            line(fp)
            line(fp, "== Tracker symbols ==")
            line(fp, "tracker_symbol_count=%d" % len(tracker_names))
            for name in tracker_names:
                line(fp, "tracker_symbol=%s address=0x%08x" % (name, by_name[name]))

            line(fp)
            line(fp, "== Interaction candidate symbols ==")
            line(fp, "candidate_symbol_count=%d" % len(candidate_names))
            for name in candidate_names[:300]:
                line(fp, "candidate_symbol=%s address=0x%08x" % (name, by_name[name]))
            if len(candidate_names) > 300:
                line(fp, "candidate_symbol_truncated=YES")

            for name in FOCUS:
                addr, body = body_for(symbols, rows, by_name, name)
                emit_body(fp, name, addr, body)

            for name in tracker_names:
                addr, body = body_for(symbols, rows, by_name, name)
                emit_body(fp, name, addr, body)

            line(fp)
            line(fp, "== Static routing facts ==")
            line(fp, "DragWindow_uses_TWindowTracker=%s" %
                 ("YES" if drag_body and body_contains(drag_body, "TWindowTracker") else "NO"))
            line(fp, "HitSelf_calls_GetThemeWindowRegionHit=%s" %
                 ("YES" if hit_body and body_contains(hit_body, "_GetThemeWindowRegionHit") else "NO"))
            line(fp, "GetThemeWindowRegionHit_calls_HIThemeGetWindowRegionHit=%s" %
                 ("YES" if region_body and body_contains(region_body, "_HIThemeGetWindowRegionHit") else "NO"))
            line(fp, "part_code_rewrite_authorized=NO")
            line(fp, "private_HIToolbox_patch_authorized=NO")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "titlebar_drag_routing_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC subject was launched.")
            line(fp, "No process was attached.")
            line(fp, "No compatibility dylib was built or loaded.")
            line(fp, "Only a temporary PPC HIToolbox slice was created and removed.")
            line(fp, "No HIToolbox, CoreUI, Rosetta cache, WindowServer, CGS, notification, or XNU state was modified.")

        print("Created: %s" % output)
        if issues:
            print("RESULT: FAIL")
            for issue in issues:
                print("validation_issue=%s" % issue)
            return 1
        print("RESULT: PASS")
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
