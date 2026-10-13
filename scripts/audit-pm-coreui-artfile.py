#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./pm-coreui-artfile.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
COREUI_RES = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources"
HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"

ART_KEYS = [
    "west.clear.colorsrgb.determinate.scrollbars",
    "west.colorsrgb.determinate.minus.scrollbars",
    "west.colorsrgb.determinate.scrollbars",
]

COREUI_COMMON = [
    "__ZN10CUIElement15LoadFromArtFileEPKh",
    "__CUIUseArtFile",
]

COREUI_SNOW = [
    "__Z23ShowArtFilePathToStdErrPKh",
    "__ZN10CUIElement4LoadEP11_QSIContextPK13CUIDescriptorlll",
    "__Z16ArtFileSetupOncev",
    "__ZN10CUIElement18CreateQSIImagePathElPK13CUIDescriptorPPK10__CFStringPhll",
    "__ZN11CUIRenderer10Draw1PieceElPK13CUIDescriptorhh",
    "__ZN11CUIRenderer4DrawE6CGRectP9CGContextPK14__CFDictionaryPS5_",
]

COREUI_LION = [
    "__Z23ShowArtFilePathToStdErrP11ArtFileInfoPKh",
    "__ZN10CUIElement4LoadEPvPK13CUIDescriptorlll",
    "__ZN11ArtFileInfo18ArtFile10SetupOnceEv",
    "__ZN11ArtFileInfo18ArtFile20SetupOnceEv",
    "__ZN11ArtFileInfo28GetArtFileInfoForScaleFactorEf",
    "__ZN10CUIElement18CreateQSIImagePathElPK13CUIDescriptorPPK10__CFStringPhll",
    "__ZN11CUIRenderer10Draw1PieceElPK13CUIDescriptorhh",
    "__ZN11CUIRenderer4DrawE6CGRectP9CGContextPK14__CFDictionaryPS5_",
]

HITOOLBOX_TARGETS = [
    "__HIThemeDrawTitleBarWidgetInRect",
    "__ZN18HIWindowButtonView8DrawSelfEsPK9__HIShapeP9CGContext",
    "__ZN10WindowData20PrepareForVisibilityEv",
    "__ShowHideWindows",
    "_ShowWindow",
]

SNOW_COREUI_CRASH_FRAMES = [
    ("__Z23ShowArtFilePathToStdErrPKh", 0x924072c4, 220),
    ("__ZN10CUIElement15LoadFromArtFileEPKh", 0x92407b38, 1840),
    ("__ZN10CUIElement4LoadEP11_QSIContextPK13CUIDescriptorlll", 0x92407c84, 132),
    ("__ZN11CUIRenderer10Draw1PieceElPK13CUIDescriptorhh", 0x923efbc8, 92),
    ("__ZN11CUIRenderer4DrawE6CGRectP9CGContextPK14__CFDictionaryPS5_", 0x923f6220, 3420),
]

SNOW_HITOOLBOX_CRASH_FRAMES = [
    ("__HIThemeDrawTitleBarWidgetInRect", 0x98a99374, 640),
    ("__ZN18HIWindowButtonView8DrawSelfEsPK9__HIShapeP9CGContext", 0x98b2cc78, 308),
    ("__ZN10WindowData20PrepareForVisibilityEv", 0x98d4dd6c, 216),
    ("__ShowHideWindows", 0x98d4e9c8, 308),
    ("_ShowWindow", 0x98d4ef44, 72),
]

FOCUSED_PRINTABLE_RE = re.compile(
    r"(west\.|colorsrgb|scrollbar|titlebar|ArtFile|SArtFile|aqua|theme)",
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


def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")


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


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True, out
    rc2, out2 = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    if rc2 == 0:
        return True, out2
    return False, out2 if out2.strip() else out


def thin_arch(src, arch, dst):
    ok, out = verify_arch(src, arch)
    if not ok:
        return False, out
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0, out


def parse_symbols(text):
    ordered = []
    by_name = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None or "(__TEXT,__text)" not in line:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        if name not in by_name:
            by_name[name] = addr
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, line))
    return rows


def symbol_rows(rows, symbols, target_name):
    target_index = None
    for i, item in enumerate(symbols):
        if item[1] == target_name:
            target_index = i
            break
    if target_index is None:
        return []
    start = symbols[target_index][0]
    end = symbols[target_index + 1][0] if target_index + 1 < len(symbols) else None
    out = []
    for addr, line in rows:
        if addr < start:
            continue
        if end is not None and addr >= end:
            break
        out.append((addr, line))
    return out


def emit_target_symbols(fp, source, label, arch, targets, tempdir, issues):
    thin = os.path.join(tempdir, "%s.%s" % (label, arch))
    ok, out = thin_arch(source, arch, thin)
    write_line(fp)
    write_line(fp, "== %s targeted slice ==" % label)
    write_line(fp, "source=%s" % source)
    write_line(fp, "arch=%s" % arch)
    if not ok:
        write_line(fp, "thin=NO")
        write_line(fp, out.rstrip())
        issues.append("%s missing required arch %s" % (label, arch))
        return {}, []

    write_line(fp, "thin=YES")
    write_line(fp, "slice_sha256=%s" % sha256(thin))

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "nm_failed")
        issues.append("%s nm failed" % label)
        return {}, []

    symbols, by_name = parse_symbols(nm_out)

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "otool_disassembly_failed")
        issues.append("%s disassembly failed" % label)
        return by_name, symbols
    rows = parse_instructions(dis_out)

    for name in targets:
        addr = by_name.get(name)
        write_line(fp)
        write_line(fp, "== target symbol: %s ==" % name)
        if addr is None:
            write_line(fp, "present=NO")
            issues.append("%s target missing: %s" % (label, name))
            continue
        write_line(fp, "present=YES")
        write_line(fp, "symbol_address=0x%x" % addr)
        body = symbol_rows(rows, symbols, name)
        write_line(fp, "instruction_lines=%d" % len(body))
        for row_addr, line in body:
            write_line(fp, line)

    return by_name, symbols


def emit_crash_map(fp, label, by_name, frames, expected_base, issues):
    write_line(fp)
    write_line(fp, "== %s Snow-PPC crash address mapping ==" % label)
    bases = []
    missing = False
    for name, absolute_addr, function_offset in frames:
        symbol_addr = by_name.get(name)
        if symbol_addr is None:
            write_line(fp, "%s=MISSING" % name)
            missing = True
            continue
        base = absolute_addr - symbol_addr - function_offset
        bases.append(base)
        write_line(
            fp,
            "%s symbol=0x%x crash=0x%x reportedOffset=%d derivedBase=0x%x" %
            (name, symbol_addr, absolute_addr, function_offset, base)
        )
    exact = (not missing and len(bases) == len(frames) and
             len(set(bases)) == 1 and bases[0] == expected_base)
    write_line(fp, "derived_base_exact=%s" % ("YES" if exact else "NO"))
    if bases:
        write_line(fp, "derived_base=0x%x" % bases[0])
    write_line(fp, "expected_base=0x%x" % expected_base)
    if not exact:
        issues.append("%s Snow-PPC crash map is not exact" % label)


def byte_value(ch):
    if isinstance(ch, int):
        return ch
    return ord(ch)


def hex_block(data):
    return "".join("%02x" % byte_value(ch) for ch in data)


def find_all(data, needle):
    out = []
    start = 0
    while True:
        pos = data.find(needle, start)
        if pos < 0:
            break
        out.append(pos)
        start = pos + 1
    return out


def printable_runs(data, min_len=6):
    out = []
    start = None
    chars = []
    for i in range(len(data)):
        v = byte_value(data[i])
        if 0x20 <= v <= 0x7e:
            if start is None:
                start = i
            chars.append(chr(v))
        else:
            if start is not None and len(chars) >= min_len:
                out.append((start, "".join(chars)))
            start = None
            chars = []
    if start is not None and len(chars) >= min_len:
        out.append((start, "".join(chars)))
    return out


def emit_resource(fp, path, label):
    write_line(fp)
    write_line(fp, "== resource: %s ==" % label)
    write_line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        return

    size = os.path.getsize(path)
    write_line(fp, "state=PRESENT")
    write_line(fp, "size=%d" % size)
    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())

    data = open(path, "rb").read()
    write_line(fp, "head256_hex=%s" % hex_block(data[:256]))
    write_line(fp, "tail256_hex=%s" % hex_block(data[-256:] if len(data) >= 256 else data))

    for key in ART_KEYS:
        needle = key.encode("ascii") if not isinstance(data, str) else key
        offsets = find_all(data, needle)
        write_line(fp, "key=%s count=%d offsets=%s" %
                   (key, len(offsets),
                    ",".join("0x%x" % x for x in offsets) if offsets else "NONE"))

    focused = []
    for offset, value in printable_runs(data):
        if FOCUSED_PRINTABLE_RE.search(value):
            focused.append((offset, value))
    write_line(fp, "focused_printable_count=%d" % len(focused))
    for offset, value in focused[:1000]:
        write_line(fp, "0x%x %s" % (offset, value))
    if len(focused) > 1000:
        write_line(fp, "additional_focused_printables_omitted=%d" % (len(focused) - 1000))


def emit_cache(fp):
    write_line(fp)
    write_line(fp, "== Rosetta shared-cache provenance ==")
    write_line(fp, "rosetta_cache_sha256=%s" %
               (sha256(ROSETTA_CACHE) if os.path.isfile(ROSETTA_CACHE) else "MISSING"))
    write_line(fp, "rosetta_cache_map_sha256=%s" %
               (sha256(ROSETTA_MAP) if os.path.isfile(ROSETTA_MAP) else "MISSING"))
    if os.path.isfile(ROSETTA_MAP):
        try:
            lines = open(ROSETTA_MAP, "r").read().splitlines()
        except IOError:
            lines = []
        hits = [line for line in lines if COREUI in line or HITOOLBOX in line]
        write_line(fp, "cache_map_framework_hit_count=%d" % len(hits))
        for line in hits[:40]:
            write_line(fp, line)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-coreui-artfile.")

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8":
            arch = "ppc7400"
            coreui_targets = COREUI_COMMON + COREUI_SNOW
        elif product == "10.7.5":
            arch = "i386"
            coreui_targets = COREUI_COMMON + COREUI_LION
        else:
            arch = None
            coreui_targets = []
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager CoreUI ArtFile contract audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % (arch if arch else "UNSUPPORTED"))
            write_line(fp, "live_boundary=Snow-PPC CoreUI code on Lion consuming release-specific CoreUI ArtFile resources")
            write_line(fp, "live_adapter_changes=NONE")

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())
            emit_cache(fp)

            write_line(fp)
            write_line(fp, "== CoreUI on-disk provenance ==")
            write_line(fp, "path=%s" % COREUI)
            if os.path.isfile(COREUI):
                write_line(fp, "sha256=%s" % sha256(COREUI))
                rc, out = run(["/usr/bin/file", COREUI])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", COREUI])
                write_line(fp, out.rstrip())
            else:
                write_line(fp, "state=MISSING")
                issues.append("CoreUI binary missing")

            write_line(fp)
            write_line(fp, "== HIToolbox on-disk provenance ==")
            write_line(fp, "path=%s" % HITOOLBOX)
            if os.path.isfile(HITOOLBOX):
                write_line(fp, "sha256=%s" % sha256(HITOOLBOX))
                rc, out = run(["/usr/bin/file", HITOOLBOX])
                write_line(fp, out.rstrip())
                rc, out = run(["/usr/bin/lipo", "-info", HITOOLBOX])
                write_line(fp, out.rstrip())
            else:
                write_line(fp, "state=MISSING")
                issues.append("HIToolbox binary missing")

            if arch:
                core_by_name, _ = emit_target_symbols(
                    fp, COREUI, "CoreUI", arch, coreui_targets, tempdir, issues
                )
                hit_by_name, _ = emit_target_symbols(
                    fp, HITOOLBOX, "HIToolbox", arch,
                    HITOOLBOX_TARGETS, tempdir, issues
                )

                old_sig = "__Z23ShowArtFilePathToStdErrPKh" in core_by_name
                new_sig = "__Z23ShowArtFilePathToStdErrP11ArtFileInfoPKh" in core_by_name
                artfile_once = "__Z16ArtFileSetupOncev" in core_by_name
                artfile10 = "__ZN11ArtFileInfo18ArtFile10SetupOnceEv" in core_by_name
                artfile20 = "__ZN11ArtFileInfo18ArtFile20SetupOnceEv" in core_by_name

                write_line(fp)
                write_line(fp, "== CoreUI contract markers ==")
                write_line(fp, "old_ShowArtFilePath_signature=%s" % ("YES" if old_sig else "NO"))
                write_line(fp, "new_ShowArtFilePath_ArtFileInfo_signature=%s" % ("YES" if new_sig else "NO"))
                write_line(fp, "legacy_ArtFileSetupOnce=%s" % ("YES" if artfile_once else "NO"))
                write_line(fp, "ArtFile10SetupOnce=%s" % ("YES" if artfile10 else "NO"))
                write_line(fp, "ArtFile20SetupOnce=%s" % ("YES" if artfile20 else "NO"))

                if product == "10.6.8":
                    emit_crash_map(
                        fp, "CoreUI", core_by_name, SNOW_COREUI_CRASH_FRAMES,
                        0x923de000, issues
                    )
                    emit_crash_map(
                        fp, "HIToolbox", hit_by_name, SNOW_HITOOLBOX_CRASH_FRAMES,
                        0x98a77000, issues
                    )

            emit_resource(fp, os.path.join(COREUI_RES, "ArtFile.bin"), "ArtFile.bin")
            emit_resource(fp, os.path.join(COREUI_RES, "ArtFile200.bin"), "ArtFile200.bin")
            emit_resource(fp, os.path.join(COREUI_RES, "SArtFile.bin"), "SArtFile.bin")

            scrollbars = os.path.join(COREUI_RES, "UI.bundle", "Contents", "Recipes", "scrollbars.xml")
            emit_resource(fp, scrollbars, "UI.bundle/Contents/Recipes/scrollbars.xml")

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No CoreUI, HIToolbox, WindowServer, distributed-notification, CGS, bootstrap, or Mach request was issued by this audit.")
            write_line(fp, "No framework, resource, Rosetta cache, service, or XNU state was modified by this audit.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

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
