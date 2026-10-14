#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import shutil
import struct
import subprocess
import sys
import tempfile

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-titlebar-rendering-contract-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
RESOURCES = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources"
ARTFILE10 = os.path.join(RESOURCES, "ArtFile.bin")
ARTFILE20 = os.path.join(RESOURCES, "ArtFile200.bin")
RECIPES = os.path.join(RESOURCES, "UI.bundle", "Contents", "Recipes")

LOAD_FROM_ARTFILE = "__ZN10CUIElement15LoadFromArtFileEPKh"
LOAD_SNOW = "__ZN10CUIElement4LoadEP11_QSIContextPK13CUIDescriptorlll"
LOAD_LION = "__ZN10CUIElement4LoadEPvPK13CUIDescriptorlll"
DRAW_1PIECE = "__ZN11CUIRenderer10Draw1PieceElPK13CUIDescriptorhh"
DRAW_WINDOW_TITLEBAR = "__ZN11CUIRenderer18DrawWindowTitleBarEPK13CUIDescriptor"
DRAW_WINDOW_FRAME_DARK = "__ZN11CUIRenderer19DrawWindowFrameDarkEPK13CUIDescriptor"
DRAW_TITLEBAR_BUTTON = "__ZN11CUIRenderer18DrawTitlebarButtonEPK13CUIDescriptor"
COPY_WINDOW_TITLEBAR_IMAGE = "__ZN11CUIRenderer23CopyWindowTitlebarImageEPK13CUIDescriptorf"
CUI_USE_ARTFILE = "__CUIUseArtFile"
ARTFILE_SETUP_SNOW = "__Z16ArtFileSetupOncev"
ARTFILE10_SETUP = "__ZN11ArtFileInfo18ArtFile10SetupOnceEv"
ARTFILE20_SETUP = "__ZN11ArtFileInfo18ArtFile20SetupOnceEv"
GET_SCALE = "__ZN11ArtFileInfo28GetArtFileInfoForScaleFactorEf"
SCALE_AVAILABLE = "__ZN10CUIElement27ArtFileScaleFactorAvailableEf"

EXPECTED = {
    "10.6.8": dict(
        build="10K549",
        arch="ppc7400",
        coreui_slice_sha256="5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839",
        art10_size=5946480,
        art10_sha256="1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",
        art20_state="MISSING",
        art20_size=0,
        art20_sha256="MISSING",
        record_count=3324,
        path_len=8,
        component_count=182,
        table_start=0x18,
        string_pool=0x5c8,
        index_start=0xc4a,
        payload_start=0xa81c,
        recipes_state="PRESENT",
        symbols=[
            LOAD_FROM_ARTFILE,
            LOAD_SNOW,
            DRAW_1PIECE,
            DRAW_WINDOW_TITLEBAR,
            DRAW_WINDOW_FRAME_DARK,
            CUI_USE_ARTFILE,
            ARTFILE_SETUP_SNOW,
        ],
    ),
    "10.7.5": dict(
        build="11G63",
        arch="i386",
        coreui_slice_sha256="5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b",
        art10_size=4765184,
        art10_sha256="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",
        art20_state="PRESENT",
        art20_size=18101720,
        art20_sha256="463bdec2bb3a3f66d35bc85e80129b8e0ea85e474e8725b093d747ffa687614f",
        record_count=2674,
        path_len=8,
        component_count=169,
        table_start=0x18,
        string_pool=0x560,
        index_start=0xb9d,
        payload_start=0x88f8,
        recipes_state="MISSING",
        symbols=[
            LOAD_FROM_ARTFILE,
            LOAD_LION,
            DRAW_1PIECE,
            DRAW_TITLEBAR_BUTTON,
            DRAW_WINDOW_TITLEBAR,
            DRAW_WINDOW_FRAME_DARK,
            COPY_WINDOW_TITLEBAR_IMAGE,
            CUI_USE_ARTFILE,
            ARTFILE10_SETUP,
            ARTFILE20_SETUP,
            GET_SCALE,
            SCALE_AVAILABLE,
        ],
    ),
}

TARGETS = [
    ("disabled-clear", ("titlebarcontrols", "close", "colorsryg", "disabled", "regularwin")),
    ("disabled-minus", ("titlebarcontrols", "colorsryg", "disabled", "minimize", "regularwin")),
    ("disabled-zoom", ("titlebarcontrols", "colorsryg", "disabled", "regularwin", "zoom")),
    ("active-clear", ("titlebarcontrols", "active", "close", "colorsryg", "regularwin")),
    ("active-minus", ("titlebarcontrols", "active", "colorsryg", "minimize", "regularwin")),
    ("active-zoom", ("titlebarcontrols", "active", "colorsryg", "regularwin", "zoom")),
]


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha_file(path):
    h = hashlib.sha256()
    fp = open(path, "rb")
    try:
        while True:
            b = fp.read(1048576)
            if not b:
                break
            h.update(b)
    finally:
        fp.close()
    return h.hexdigest()


def sha_bytes(data):
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def byte_value(ch):
    return ch if isinstance(ch, int) else ord(ch)


def u16(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def hex_bytes(data):
    return "".join("%02x" % byte_value(ch) for ch in data)


def make_bytes(vals):
    return "".join(chr(v) for v in vals)


def cstring(data, off, limit=512):
    if off < 0 or off >= len(data):
        return None
    out = []
    for pos in range(off, min(len(data), off + limit)):
        v = byte_value(data[pos])
        if v == 0:
            return "".join(out)
        if v < 0x20 or v > 0x7e:
            return None
        out.append(chr(v))
    return None


def parse_header(data):
    if len(data) < 24:
        return None
    return dict(
        record_count=u16(data, 0),
        path_len=u16(data, 2),
        component_count=u16(data, 4),
        table_start=u32(data, 8),
        string_pool=u32(data, 12),
        index_start=u32(data, 16),
        payload_start=u32(data, 20),
    )


def parse_dictionary(data, header):
    byname = {}
    byid = {}
    for ident in range(1, header["component_count"] + 1):
        ent = header["table_start"] + (ident - 1) * 8
        if ent + 8 > header["string_pool"] or ent + 8 > len(data):
            continue
        text = cstring(data, header["string_pool"] + u32(data, ent))
        if text is not None:
            byname[text] = ident
            byid[ident] = text
    return byname, byid


def parse_index(data, header):
    out = []
    rec_size = header["path_len"] + 4
    for i in range(header["record_count"]):
        off = header["index_start"] + i * rec_size
        if off + rec_size > len(data):
            break
        rel = u32(data, off)
        out.append(dict(
            index=i,
            record_off=off,
            payload_rel=rel,
            payload_off=header["payload_start"] + rel,
            key=data[off + 4:off + rec_size],
        ))
    return out


def semantic_key(parts, byname, path_len):
    ids = []
    for name in parts:
        if name not in byname:
            return None
        ids.append(byname[name])
    if len(ids) > path_len:
        return None
    return make_bytes(ids + [0] * (path_len - len(ids)))


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


def parse_symbols(text):
    ordered = []
    by_name = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in line:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        ordered.append((addr, name))
        if name not in by_name:
            by_name[name] = addr
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    out = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            out.append((addr, line))
    return out


def symbol_body(rows, symbols, target):
    idx = None
    for i, item in enumerate(symbols):
        if item[1] == target:
            idx = i
            break
    if idx is None:
        return []
    start = symbols[idx][0]
    end = symbols[idx + 1][0] if idx + 1 < len(symbols) else None
    return [(addr, line) for addr, line in rows
            if addr >= start and (end is None or addr < end)]


def verify_arch(path, arch):
    rc, out = run(["/usr/bin/lipo", path, "-verify_arch", arch])
    if rc == 0:
        return True
    rc, out = run(["/usr/bin/lipo", "-verify_arch", arch, path])
    return rc == 0


def thin_arch(src, arch, dst):
    if not verify_arch(src, arch):
        return False
    rc, out = run(["/usr/bin/lipo", src, "-thin", arch, "-output", dst])
    return rc == 0


def emit_coreui(fp, tmpdir, expected, issues):
    thin = os.path.join(tmpdir, "CoreUI.%s" % expected["arch"])
    write_line(fp)
    write_line(fp, "== CoreUI rendering/scale contract ==")
    write_line(fp, "coreui_path=%s" % COREUI)
    write_line(fp, "required_arch=%s" % expected["arch"])
    if not os.path.isfile(COREUI):
        write_line(fp, "coreui_state=MISSING")
        issues.append("CoreUI missing")
        return
    if not thin_arch(COREUI, expected["arch"], thin):
        write_line(fp, "coreui_thin=NO")
        issues.append("CoreUI missing required arch")
        return
    write_line(fp, "coreui_thin=YES")
    digest = sha_file(thin)
    write_line(fp, "coreui_slice_sha256=%s" % digest)
    if digest != expected["coreui_slice_sha256"]:
        issues.append("CoreUI slice SHA mismatch")

    rc1, nm = run(["/usr/bin/nm", "-nm", thin])
    rc2, dis = run(["/usr/bin/otool", "-tvV", thin])
    if rc1 != 0 or rc2 != 0:
        write_line(fp, "coreui_static_tools=FAIL")
        issues.append("CoreUI static tools failed")
        return
    write_line(fp, "coreui_static_tools=PASS")
    symbols, byname = parse_symbols(nm)
    rows = parse_instructions(dis)
    for name in expected["symbols"]:
        write_line(fp)
        write_line(fp, "== CoreUI symbol: %s ==" % name)
        if name not in byname:
            write_line(fp, "present=NO")
            issues.append("CoreUI target missing: %s" % name)
            continue
        body = symbol_body(rows, symbols, name)
        write_line(fp, "present=YES")
        write_line(fp, "symbol_address=0x%x" % byname[name])
        write_line(fp, "instruction_lines=%d" % len(body))
        for addr, line in body:
            write_line(fp, line)


def validate_archive_identity(path, expected_size, expected_sha, state, label, issues):
    present = os.path.isfile(path)
    actual_state = "PRESENT" if present else "MISSING"
    if actual_state != state:
        issues.append("%s state mismatch" % label)
    if not present:
        return None, None, None
    data = open(path, "rb").read()
    digest = sha_file(path)
    if len(data) != expected_size:
        issues.append("%s size mismatch" % label)
    if digest != expected_sha:
        issues.append("%s SHA mismatch" % label)
    return data, digest, parse_header(data)


def emit_word_views(fp, prefix):
    vals16 = [u16(prefix, off) for off in range(0, len(prefix), 2)]
    vals32 = [u32(prefix, off) for off in range(0, len(prefix), 4)]
    write_line(fp, "header_u16=" + ",".join("%04x" % v for v in vals16))
    write_line(fp, "header_u32=" + ",".join("%08x" % v for v in vals32))


def emit_archive(fp, path, label, expected, state, expected_size, expected_sha, issues):
    write_line(fp)
    write_line(fp, "== %s ==" % label)
    write_line(fp, "path=%s" % path)
    data, digest, header = validate_archive_identity(
        path, expected_size, expected_sha, state, label, issues)
    if data is None:
        write_line(fp, "state=MISSING")
        return
    write_line(fp, "state=PRESENT")
    write_line(fp, "size=%d" % len(data))
    write_line(fp, "sha256=%s" % digest)

    if header is None:
        write_line(fp, "header=UNAVAILABLE")
        issues.append("%s header unavailable" % label)
        return

    for key in ("record_count", "path_len", "component_count",
                "table_start", "string_pool", "index_start", "payload_start"):
        expected_value = expected[key]
        actual = header[key]
        write_line(fp, "%s=%s" % (
            key,
            ("0x%x" % actual) if key not in ("record_count", "path_len", "component_count")
            else str(actual)))
        if actual != expected_value:
            issues.append("%s header %s mismatch" % (label, key))

    byname, byid = parse_dictionary(data, header)
    records = parse_index(data, header)
    if len(records) != header["record_count"]:
        issues.append("%s index count mismatch" % label)

    payload_offsets = sorted(set(
        item["payload_off"] for item in records
        if 0 <= item["payload_off"] <= len(data)))

    prefixes = []
    write_line(fp)
    write_line(fp, "== %s exact-six records ==" % label)
    for target_name, semantic in TARGETS:
        key = semantic_key(semantic, byname, header["path_len"])
        hits = [r for r in records if key is not None and r["key"] == key]
        write_line(fp, "path=%s" % target_name)
        write_line(fp, "semantic_path=%s" % ".".join(semantic))
        write_line(fp, "local_key=%s" % (hex_bytes(key) if key is not None else "UNRESOLVED"))
        write_line(fp, "local_index_hits=%d" % len(hits))
        if key is None:
            issues.append("%s %s semantic key unresolved" % (label, target_name))
        if len(hits) != 1:
            issues.append("%s %s hit count %d" % (label, target_name, len(hits)))
        for rec in hits:
            start = rec["payload_off"]
            later = [x for x in payload_offsets if x > start]
            end = later[0] if later else len(data)
            span = data[start:end] if 0 <= start <= end <= len(data) else b""
            prefix = span[:0x68]
            prefixes.append(prefix)
            write_line(fp, "index=%d" % rec["index"])
            write_line(fp, "record_off=0x%x" % rec["record_off"])
            write_line(fp, "payload_rel=0x%x" % rec["payload_rel"])
            write_line(fp, "payload_off=0x%x" % start)
            write_line(fp, "payload_span_length=%d" % len(span))
            write_line(fp, "payload_span_sha256=%s" % sha_bytes(span))
            write_line(fp, "header_length=%d" % len(prefix))
            write_line(fp, "header_sha256=%s" % sha_bytes(prefix))
            write_line(fp, "header_hex=%s" % hex_bytes(prefix))
            if len(prefix) == 0x68:
                emit_word_views(fp, prefix)
                write_line(fp, "header_body_offset_u32_at_0x20=0x%x" % u32(prefix, 0x20))
            else:
                issues.append("%s %s header shorter than 0x68" % (label, target_name))
            write_line(fp, "body_prefix_0x40_hex=%s" % hex_bytes(span[0x68:0xa8]))
        write_line(fp)

    if len(prefixes) == 6:
        write_line(fp, "exact_six_header_unique_count=%d" %
                   len(set(hex_bytes(x) for x in prefixes)))
        write_line(fp, "exact_six_body_offset_0x68_count=%d" %
                   sum(1 for x in prefixes if len(x) == 0x68 and u32(x, 0x20) == 0x68))


def emit_recipes(fp, expected, issues):
    present = os.path.isdir(RECIPES)
    state = "PRESENT" if present else "MISSING"
    write_line(fp)
    write_line(fp, "== CoreUI recipe tree ==")
    write_line(fp, "path=%s" % RECIPES)
    write_line(fp, "state=%s" % state)
    if state != expected["recipes_state"]:
        issues.append("recipe tree state mismatch")
    if not present:
        write_line(fp, "file_count=0")
        write_line(fp, "title_or_window_recipe_count=0")
        return
    names = []
    focused = []
    for root, dirs, files in os.walk(RECIPES):
        dirs.sort()
        files.sort()
        for name in files:
            full = os.path.join(root, name)
            rel = os.path.relpath(full, RECIPES)
            names.append(rel)
            low = rel.lower()
            if "title" in low or "window" in low:
                focused.append(rel)
    write_line(fp, "file_count=%d" % len(names))
    write_line(fp, "title_or_window_recipe_count=%d" % len(focused))
    for rel in focused:
        write_line(fp, "focused_recipe=%s" % rel)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./ppc-carbon-gui-titlebar-rendering-contract.txt"
    issues = []
    tmpdir = tempfile.mkdtemp(prefix="ppc-carbon-titlebar-rendering.")
    try:
        rc, out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = out.strip() if rc == 0 else "UNKNOWN"
        rc, out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = out.strip() if rc == 0 else "UNKNOWN"
        expected = EXPECTED.get(product)
        if expected is None:
            expected = EXPECTED["10.7.5"]
            issues.append("unsupported product version: %s" % product)
        if build != expected["build"]:
            issues.append("unexpected build version")

        fp = open(report, "w")
        try:
            write_line(fp, "== PPC Carbon GUI titlebar rendering contract audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "required_arch=%s" % expected["arch"])

            emit_archive(
                fp, ARTFILE10, "ArtFile10",
                expected, "PRESENT",
                expected["art10_size"], expected["art10_sha256"], issues)
            emit_archive(
                fp, ARTFILE20, "ArtFile20",
                expected, expected["art20_state"],
                expected["art20_size"], expected["art20_sha256"], issues)
            emit_recipes(fp, expected, issues)
            emit_coreui(fp, tmpdir, expected, issues)

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            if issues:
                for item in issues:
                    write_line(fp, "validation_issue=%s" % item)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "archive_and_renderer_contract_exact=YES")
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "The analyzer opened only local CoreUI and CoreUI resource files for reading.")
            write_line(fp, "It created only a temporary architecture slice for static disassembly.")
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No process was attached.")
            write_line(fp, "No compatibility artifact was built or installed.")
            write_line(fp, "No framework, ArtFile, recipe, Rosetta cache, service, WindowServer, or XNU state was modified.")
        finally:
            fp.close()

        print("Created: %s" % report)
        if issues:
            print("RESULT: FAIL")
            for item in issues:
                print("validation_issue=%s" % item)
            return 1
        print("RESULT: PASS")
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
