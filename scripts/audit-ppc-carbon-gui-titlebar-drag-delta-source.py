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
AUDIT_CONTRACT = "carbon-gui-titlebar-drag-delta-source-v1"

HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"
COREGRAPHICS = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_CACHE_SHA = "2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_MAP_SHA = "66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"

EXPECTED = {
    "10.6.8": dict(
        mode="snow",
        build="10K549",
        arch="ppc7400",
        hitoolbox_sha="fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f",
        coregraphics_sha="2e2fa8b25aff0fd85565d67c585dd368e79eee5d12716eac2b1c3511a1aadd18",
    ),
    "10.7.5": dict(
        mode="lion",
        build="11G63",
        arch="i386",
        hitoolbox_sha="b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6",
        coregraphics_sha="fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192",
    ),
}

SNOW_REQUIRED_HITOOLBOX = [
    "_DragWindow",
    "__ZN12TDragTrackerC2EP15OpaqueWindowPtr5PointPK4Rect",
    "__ZN14TWindowTrackerC2EP15OpaqueWindowPtr5Pointmm25CoreDockDragWindowMessageS3_PK10__CFStringPK4Rect",
    "__ZN14TWindowTracker11TrackWindowEv",
    "__ZN12TDragTracker12OnMouseMovedER5Point",
    "__ZN14TWindowTracker12OnMouseMovedER5PointS0_S0_S0_",
]
REQUIRED_COREGRAPHICS = [
    "_CGSMoveWindow",
    "_CGSMoveWindowList",
    "__CGSMoveWindow",
]

HITOOLBOX_FOCUS_RE = re.compile(
    r"(DragWindow|TDragTracker|TWindowTracker|TrackWindow|OnMouseMoved|"
    r"RelocateWindowImage|CalculateLimitRegion|ShouldUpdateBounds|"
    r"GetMouse|MouseLocation|Event.*Location|Location.*Event)",
    re.I,
)
COREGRAPHICS_FOCUS_RE = re.compile(
    r"(CGSMoveWindow|CGSWindowBounds|CGSGetWindowTransform|CGSGetWindowBounds)",
    re.I,
)
POINT_CONVERSION_RE = re.compile(
    r"\b(lha|lhz|sth|extsh|srawi|rlwinm|lfs|stfs|lfd|stfd|fctiw|fctiwz|"
    r"fcfid|frsp|cvtsi2ss|cvtss2si|movss|movswl|movzwl|movw|pinsrw|pextrw)\b",
    re.I,
)
CALL_RE = re.compile(
    r"\b(bl|bla|b|beq|bne|bc|call|calll|jmp|jmpl)\b",
    re.I,
)
PROTOCOL_RE = re.compile(r"0x0*(7218|727c)\b", re.I)


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
    ordered.sort()
    return ordered, by_name


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


def emit_symbol(fp, image_name, symbols, rows, by_name, name):
    addr, body = body_for(symbols, rows, by_name, name)
    line(fp)
    line(fp, "== %s focus symbol ==" % image_name)
    line(fp, "name=%s" % name)
    line(fp, "present=%s" % ("YES" if addr is not None else "NO"))
    if addr is None:
        return
    line(fp, "address=0x%08x" % addr)
    line(fp, "instruction_lines=%d" % len(body))
    for row_addr, raw in body:
        line(fp, raw)
    line(fp, "-- point/conversion instructions --")
    conversion_count = 0
    for row_addr, raw in body:
        if POINT_CONVERSION_RE.search(raw):
            conversion_count += 1
            line(fp, raw)
    line(fp, "point_conversion_instruction_count=%d" % conversion_count)
    line(fp, "-- call/branch lines --")
    for row_addr, raw in body:
        if CALL_RE.search(raw):
            line(fp, raw)


def emit_callers(fp, image_name, symbols, rows, by_name, targets):
    line(fp)
    line(fp, "== %s direct caller inventory ==" % image_name)
    for target in targets:
        target_addr = by_name.get(target)
        if target_addr is None:
            line(fp, "target=%s present=NO" % target)
            continue
        found = []
        for addr, raw in rows:
            if target in raw:
                caller_addr, caller_name = containing_symbol(symbols, addr)
                if caller_name == target:
                    continue
                found.append((caller_addr, caller_name, addr, raw))
        line(fp, "target=%s address=0x%08x direct_reference_lines=%d" %
             (target, target_addr, len(found)))
        for caller_addr, caller_name, addr, raw in found:
            line(fp, "caller target=%s caller=%s caller_start=%s call_site=0x%08x raw=%s" % (
                target,
                caller_name or "UNRESOLVED",
                ("0x%08x" % caller_addr) if caller_addr is not None else "UNRESOLVED",
                addr,
                raw,
            ))


def load_image(src, arch, tmpdir, stem, expected_sha, issues):
    result = dict(symbols=[], by_name={}, rows=[], sha="MISSING", thin_path="")
    if not os.path.isfile(src):
        issues.append("%s missing" % stem)
        return result
    dst = os.path.join(tmpdir, "%s.%s" % (stem, arch))
    if not thin(src, arch, dst):
        issues.append("%s %s slice unavailable" % (stem, arch))
        return result
    result["thin_path"] = dst
    result["sha"] = sha256(dst)
    if result["sha"] != expected_sha:
        issues.append("%s SHA mismatch" % stem)
    rc, nm = run(["/usr/bin/nm", "-nm", dst])
    if rc != 0:
        issues.append("%s nm failed" % stem)
    else:
        result["symbols"], result["by_name"] = parse_symbols(nm)
    rc, dis = run(["/usr/bin/otool", "-tvV", dst])
    if rc != 0:
        issues.append("%s otool disassembly failed" % stem)
    else:
        result["rows"] = parse_rows(dis)
    return result


def main():
    if len(sys.argv) != 2:
        print("usage: %s OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    output = sys.argv[1]
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-drag-delta-source.")
    try:
        rc, product = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product.strip() if rc == 0 else "UNKNOWN"
        rc, build = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build.strip() if rc == 0 else "UNKNOWN"
        cfg = EXPECTED.get(product)
        if cfg is None:
            issues.append("unsupported product version")
            cfg = dict(mode="unknown", build="UNKNOWN", arch="i386",
                       hitoolbox_sha="", coregraphics_sha="")
        elif build != cfg["build"]:
            issues.append("unexpected build version")

        cache_sha = sha256(ROSETTA_CACHE) if os.path.isfile(ROSETTA_CACHE) else "MISSING"
        map_sha = sha256(ROSETTA_MAP) if os.path.isfile(ROSETTA_MAP) else "MISSING"
        if cache_sha != EXPECTED_CACHE_SHA:
            issues.append("Rosetta cache SHA mismatch")
        if map_sha != EXPECTED_MAP_SHA:
            issues.append("Rosetta map SHA mismatch")

        hit = load_image(HITOOLBOX, cfg["arch"], tmpdir, "HIToolbox",
                         cfg["hitoolbox_sha"], issues)
        cg = load_image(COREGRAPHICS, cfg["arch"], tmpdir, "CoreGraphics",
                        cfg["coregraphics_sha"], issues)

        if cfg["mode"] == "snow":
            for name in SNOW_REQUIRED_HITOOLBOX:
                if name not in hit["by_name"]:
                    issues.append("required Snow HIToolbox symbol missing: %s" % name)
        for name in REQUIRED_COREGRAPHICS:
            if name not in cg["by_name"]:
                issues.append("required CoreGraphics symbol missing: %s" % name)

        hit_focus = [name for addr, name in hit["symbols"]
                     if HITOOLBOX_FOCUS_RE.search(name)]
        cg_focus = [name for addr, name in cg["symbols"]
                    if COREGRAPHICS_FOCUS_RE.search(name)]

        with open(output, "w") as fp:
            line(fp, "== PPC Carbon GUI titlebar drag delta-source static audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            line(fp, "mode=%s" % cfg["mode"])
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "required_arch=%s" % cfg["arch"])
            line(fp, "runtime_ppc_hitoolbox_contract=%s" %
                 ("local_snow_ppc_reference" if cfg["mode"] == "snow"
                  else "accepted_identical_snow_ppc_cache"))
            line(fp, "native_lion_role=%s" %
                 ("reference_only" if cfg["mode"] == "lion" else "not_applicable"))

            line(fp)
            line(fp, "== Provenance ==")
            line(fp, "hitoolbox_slice_sha256=%s" % hit["sha"])
            line(fp, "hitoolbox_slice_exact=%s" %
                 ("YES" if hit["sha"] == cfg["hitoolbox_sha"] else "NO"))
            line(fp, "coregraphics_slice_sha256=%s" % cg["sha"])
            line(fp, "coregraphics_slice_exact=%s" %
                 ("YES" if cg["sha"] == cfg["coregraphics_sha"] else "NO"))
            line(fp, "rosetta_cache_sha256=%s" % cache_sha)
            line(fp, "rosetta_cache_map_sha256=%s" % map_sha)

            line(fp)
            line(fp, "== Live v9 anchor ==")
            line(fp, "legacy_move_request_id=0x00007218")
            line(fp, "legacy_move_reply_id=0x0000727c")
            line(fp, "legacy_move_send_size=0x0000002c")
            line(fp, "legacy_move_receive_size=0x0000002c")
            line(fp, "live_lion_first_bad_dx=-317")
            line(fp, "live_lion_first_bad_dy=-98")
            line(fp, "live_lion_second_bad_dy=17118")
            line(fp, "live_lion_second_bad_dy_hex=0x000042de")
            line(fp, "float_111_high_halfword_hex=0x42de")
            line(fp, "point_float_alias_hypothesis=DIAGNOSTIC_ONLY_NOT_AUTHORIZED")

            emit_callers(fp, "HIToolbox", hit["symbols"], hit["rows"],
                         hit["by_name"], SNOW_REQUIRED_HITOOLBOX)
            emit_callers(fp, "CoreGraphics", cg["symbols"], cg["rows"],
                         cg["by_name"], REQUIRED_COREGRAPHICS)

            line(fp)
            line(fp, "== HIToolbox focus inventory ==")
            line(fp, "focus_symbol_count=%d" % len(hit_focus))
            for name in hit_focus:
                line(fp, "focus_symbol=%s address=0x%08x" %
                     (name, hit["by_name"][name]))

            line(fp)
            line(fp, "== CoreGraphics focus inventory ==")
            line(fp, "focus_symbol_count=%d" % len(cg_focus))
            for name in cg_focus:
                line(fp, "focus_symbol=%s address=0x%08x" %
                     (name, cg["by_name"][name]))

            emitted = set()
            for name in hit_focus:
                if name in emitted:
                    continue
                emitted.add(name)
                emit_symbol(fp, "HIToolbox", hit["symbols"], hit["rows"],
                            hit["by_name"], name)

            emitted = set()
            for name in cg_focus:
                if name in emitted:
                    continue
                emitted.add(name)
                emit_symbol(fp, "CoreGraphics", cg["symbols"], cg["rows"],
                            cg["by_name"], name)

            line(fp)
            line(fp, "== CoreGraphics 0x7218/0x727c immediate contexts ==")
            protocol_hits = 0
            for addr, raw in cg["rows"]:
                if PROTOCOL_RE.search(raw):
                    protocol_hits += 1
                    caller_addr, caller_name = containing_symbol(cg["symbols"], addr)
                    line(fp, "protocol_context symbol=%s symbol_start=%s line=%s" % (
                        caller_name or "UNRESOLVED",
                        ("0x%08x" % caller_addr) if caller_addr is not None else "UNRESOLVED",
                        raw,
                    ))
            line(fp, "protocol_immediate_context_count=%d" % protocol_hits)

            line(fp)
            line(fp, "== Questions ==")
            line(fp, "question_1=How does DragWindow pass the initial QuickDraw Point into TDragTracker?")
            line(fp, "question_2=Where are later cursor Points obtained and converted before TDragTracker::OnMouseMoved?")
            line(fp, "question_3=Which instructions derive the two CGSMoveWindow scalar deltas?")
            line(fp, "question_4=Can the 0x42de vertical delta be traced to the high halfword of float 111.0 before CoreGraphics transport?")
            line(fp, "question_5=Is the 0x7218/0x727c move protocol release-stable, leaving the payload already corrupt at entry?")
            line(fp, "move_payload_rewrite_authorized=NO")
            line(fp, "private_HIToolbox_patch_authorized=NO")
            line(fp, "outofline_event_adapter_authorized=NO")
            line(fp, "notification_policy_change_authorized=NO")
            line(fp, "xnu_change_authorized=NO")

            line(fp)
            line(fp, "== Validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "titlebar_drag_delta_source_audit_exact=YES")
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Integrity ==")
            line(fp, "No PowerPC application was launched by this audit.")
            line(fp, "No mouse or titlebar gesture was issued by this audit.")
            line(fp, "No CGS, WindowServer, Mach, or notification request was issued by this audit.")
            line(fp, "No HIToolbox, CoreGraphics, Rosetta cache, WindowServer, dyld, or XNU state was modified.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

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
