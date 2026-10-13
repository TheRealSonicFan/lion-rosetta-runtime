#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./pm-coreui-theme.txt"
ANALYZER_VERSION = "1"

ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
COREUI_RES = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources"
HITOOLBOX = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox"
HITOOLBOX_RES = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Resources"

ARCH_CANDIDATES = ["ppc7400", "ppc", "i386", "x86_64"]

COREUI_SYMBOL_RE = re.compile(
    r"(ShowArtFilePathToStdErr|LoadFromArtFile|CUIElement|CUIRenderer|"
    r"CUIDescriptor|ArtFile|Draw1Piece)",
    re.I,
)

HITOOLBOX_SYMBOL_RE = re.compile(
    r"(HIThemeDrawTitleBarWidgetInRect|HIWindowButtonView|DrawSelf|"
    r"DrawCacheOrSelf|RecursiveDrawComposited|DrawComposited|"
    r"EraseWindowRegionInternal|PaintWindow|PrepareForVisibility|"
    r"ShowHideWindows|ShowWindow)",
    re.I,
)

STRING_RE = re.compile(
    r"(Invalid ArtFile Path|ArtFile|art file|\.car\b|\.rsrc\b|"
    r"west\.|colorsrgb|scrollbar|titlebar|window button|appearance|"
    r"theme|aqua|coreui|cuidescriptor)",
    re.I,
)

IMPORT_RE = re.compile(
    r"(fprintf|vfprintf|fwrite|fputs|puts|strlen|strnlen|strcmp|strncmp|"
    r"memcpy|memmove|malloc|calloc|realloc|free|CFString|CFDictionary|"
    r"CGContext|CGColor|HITheme|Theme|CUI)",
    re.I,
)

RESOURCE_RE = re.compile(
    r"(art|theme|aqua|appearance|\.car$|\.rsrc$|extras|coreui|scrollbar)",
    re.I,
)

CALL_RE = re.compile(r"\b(bl|bla|call|calll|jmp|jmpl)\b", re.I)


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
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None or "(__TEXT,__text)" not in line:
            continue
        ordered.append((addr, parts[-1]))
    ordered.sort()
    return ordered


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


def group_rows_by_symbol(rows, symbols):
    groups = {}
    if not symbols:
        return groups
    si = 0
    for addr, line in rows:
        while si + 1 < len(symbols) and symbols[si + 1][0] <= addr:
            si += 1
        if symbols[si][0] <= addr:
            groups.setdefault(si, []).append((addr, line))
    return groups


def emit_cache_provenance(fp):
    write_line(fp)
    write_line(fp, "== Rosetta shared-cache provenance ==")
    if os.path.isfile(ROSETTA_CACHE):
        write_line(fp, "rosetta_cache_sha256=%s" % sha256(ROSETTA_CACHE))
    else:
        write_line(fp, "rosetta_cache=MISSING")

    if os.path.isfile(ROSETTA_MAP):
        write_line(fp, "rosetta_cache_map_sha256=%s" % sha256(ROSETTA_MAP))
        try:
            data = open(ROSETTA_MAP, "r").read()
            hits = []
            for line in data.splitlines():
                if COREUI in line or HITOOLBOX in line:
                    hits.append(line)
            write_line(fp, "cache_map_coreui_hit_count=%d" %
                       len([x for x in hits if COREUI in x]))
            write_line(fp, "cache_map_hitoolbox_hit_count=%d" %
                       len([x for x in hits if HITOOLBOX in x]))
            for line in hits[:80]:
                write_line(fp, line)
            if len(hits) > 80:
                write_line(fp, "additional_cache_map_hits_omitted=%d" %
                           (len(hits) - 80))
        except IOError as e:
            write_line(fp, "rosetta_cache_map_read_error=%s" % e)
    else:
        write_line(fp, "rosetta_cache_map=MISSING")


def emit_dependencies(fp, thin):
    write_line(fp, "-- linked libraries --")
    rc, out = run(["/usr/bin/otool", "-L", thin])
    if rc == 0:
        for line in out.splitlines():
            write_line(fp, line)
    else:
        write_line(fp, "otool_L_failed")


def emit_focused_cstrings(fp, thin):
    write_line(fp, "-- focused cstrings --")
    rc, out = run(["/usr/bin/otool", "-v", "-s", "__TEXT", "__cstring", thin])
    if rc != 0:
        write_line(fp, "otool_cstring_dump_failed")
        return
    hits = [line for line in out.splitlines() if STRING_RE.search(line)]
    write_line(fp, "focused_cstring_hit_count=%d" % len(hits))
    for line in hits[:1200]:
        write_line(fp, line)
    if len(hits) > 1200:
        write_line(fp, "additional_cstring_hits_omitted=%d" % (len(hits) - 1200))


def emit_focused_imports(fp, thin):
    write_line(fp, "-- focused undefined/imported symbols --")
    rc, out = run(["/usr/bin/nm", "-m", thin])
    if rc != 0:
        write_line(fp, "nm_m_failed")
        return
    hits = []
    for line in out.splitlines():
        if "undefined" in line.lower() and IMPORT_RE.search(line):
            hits.append(line)
    write_line(fp, "focused_import_count=%d" % len(hits))
    for line in hits[:800]:
        write_line(fp, line)
    if len(hits) > 800:
        write_line(fp, "additional_import_hits_omitted=%d" % (len(hits) - 800))


def emit_symbol_window(fp, symbols, groups, index):
    addr, name = symbols[index]
    rows = groups.get(index, [])
    write_line(fp)
    write_line(fp, "== symbol: %s ==" % name)
    write_line(fp, "symbol_address=0x%x" % addr)
    write_line(fp, "instruction_lines=%d" % len(rows))
    write_line(fp, "-- full symbol window --")
    for row_addr, line in rows:
        write_line(fp, line)

    write_line(fp, "-- call/branch lines --")
    calls = [line for row_addr, line in rows if CALL_RE.search(line)]
    if calls:
        for line in calls:
            write_line(fp, line)
    else:
        write_line(fp, "NONE")


def inspect_slice(fp, source, label, arch, tempdir, symbol_re, issues):
    safe_label = label.replace("/", "_")
    thin = os.path.join(tempdir, "%s.%s" % (safe_label, arch))
    ok, out = thin_arch(source, arch, thin)
    if not ok:
        return False

    write_line(fp)
    write_line(fp, "== %s slice %s ==" % (label, arch))
    write_line(fp, "slice_sha256=%s" % sha256(thin))
    emit_dependencies(fp, thin)
    emit_focused_cstrings(fp, thin)
    emit_focused_imports(fp, thin)

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        write_line(fp, "nm_failed")
        issues.append("%s %s nm failed" % (label, arch))
        return True

    symbols = parse_symbols(nm_out)
    candidates = []
    for i, item in enumerate(symbols):
        if symbol_re.search(item[1]):
            candidates.append(i)

    write_line(fp, "-- focused text symbols --")
    write_line(fp, "parsed_text_symbols=%d" % len(symbols))
    write_line(fp, "focused_symbol_count=%d" % len(candidates))
    for i in candidates[:240]:
        write_line(fp, "%s@0x%x" % (symbols[i][1], symbols[i][0]))
    if len(candidates) > 240:
        write_line(fp, "additional_focused_symbols_omitted=%d" %
                   (len(candidates) - 240))

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "otool_disassembly_failed")
        issues.append("%s %s disassembly failed" % (label, arch))
        return True

    rows = parse_instructions(dis_out)
    groups = group_rows_by_symbol(rows, symbols)
    write_line(fp, "parsed_instruction_lines=%d" % len(rows))

    # Emit at most the first 40 focused symbol bodies.  This captures the
    # crash-path functions while bounding report size if a framework exports
    # many similarly named helpers.
    for i in candidates[:40]:
        emit_symbol_window(fp, symbols, groups, i)

    return True


def inspect_binary(fp, path, label, symbol_re, tempdir, issues):
    write_line(fp)
    write_line(fp, "== %s binary ==" % label)
    write_line(fp, "path=%s" % path)
    if not os.path.isfile(path):
        write_line(fp, "state=MISSING")
        issues.append("%s binary missing" % label)
        return

    write_line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/file", path])
    write_line(fp, out.rstrip())
    rc, out = run(["/usr/bin/lipo", "-info", path])
    write_line(fp, out.rstrip())

    inspected = []
    seen_hashes = set()
    for arch in ARCH_CANDIDATES:
        ok, verify_out = verify_arch(path, arch)
        if not ok:
            continue
        probe = os.path.join(tempdir, "probe.%s.%s" % (label, arch))
        ok, thin_out = thin_arch(path, arch, probe)
        if not ok:
            continue
        digest = sha256(probe)
        try:
            os.unlink(probe)
        except OSError:
            pass
        if digest in seen_hashes:
            continue
        seen_hashes.add(digest)
        inspected.append(arch)
        inspect_slice(fp, path, label, arch, tempdir, symbol_re, issues)

    write_line(fp)
    write_line(fp, "%s_inspected_arches=%s" %
               (label.lower(), ",".join(inspected) if inspected else "NONE"))
    if not inspected:
        issues.append("%s has no inspectable candidate architecture" % label)


def emit_resource_inventory(fp, root, label):
    write_line(fp)
    write_line(fp, "== %s focused resource inventory ==" % label)
    write_line(fp, "root=%s" % root)
    if not os.path.isdir(root):
        write_line(fp, "state=MISSING")
        return

    all_files = 0
    hits = []
    for base, dirs, files in os.walk(root):
        dirs.sort()
        files.sort()
        for name in files:
            all_files += 1
            full = os.path.join(base, name)
            rel = os.path.relpath(full, root)
            if RESOURCE_RE.search(rel):
                try:
                    size = os.path.getsize(full)
                except OSError:
                    size = -1
                hits.append((rel, size, sha256(full)))

    write_line(fp, "resource_file_count=%d" % all_files)
    write_line(fp, "focused_resource_count=%d" % len(hits))
    for rel, size, digest in hits[:600]:
        write_line(fp, "%s size=%d sha256=%s" % (rel, size, digest))
    if len(hits) > 600:
        write_line(fp, "additional_focused_resources_omitted=%d" %
                   (len(hits) - 600))


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-coreui-theme.")

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product not in ("10.6.8", "10.7.5"):
            issues.append("unsupported product version: %s" % product)

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager ShowWindow CoreUI/theme static audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "live_boundary=post-exact-seven ShowWindow SIGSEGV in CoreUI diagnostic path")
            write_line(fp, "audit_scope=CoreUI and HIToolbox titlebar/theme-art path plus focused resources")
            write_line(fp, "live_adapter_changes=NONE")

            rc, out = run(["/usr/sbin/sysctl", "kern.exec.archhandler.powerpc"])
            write_line(fp, out.rstrip())

            emit_cache_provenance(fp)
            inspect_binary(fp, COREUI, "CoreUI", COREUI_SYMBOL_RE, tempdir, issues)
            inspect_binary(fp, HITOOLBOX, "HIToolbox", HITOOLBOX_SYMBOL_RE, tempdir, issues)
            emit_resource_inventory(fp, COREUI_RES, "CoreUI")
            emit_resource_inventory(fp, HITOOLBOX_RES, "HIToolbox")

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
            write_line(fp, "No framework, resource, Rosetta, dyld, cache, launchd, service, or XNU state was modified by this audit.")
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
