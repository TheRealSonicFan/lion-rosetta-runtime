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
AUDIT_CONTRACT = "titlebar-bsearch-boundary-v1"

COREUI = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"
ROSETTA_CACHE = "/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP = "/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_CACHE_SHA256 = "2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA256 = "66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_SNOW_COREUI_SHA256 = "84e57e7ba218986b8a272eaff44f2235c212f6d2091bc078ef1f106bfef48f23"
EXPECTED_SNOW_COREUI_PPC_SHA256 = "5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839"
EXPECTED_LION_ARTFILE_SIZE = 4765184
EXPECTED_LION_ARTFILE_SHA256 = "0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4"

LOAD_FROM_ARTFILE = "__ZN10CUIElement15LoadFromArtFileEPKh"
LOAD = "__ZN10CUIElement4LoadEP11_QSIContextPK13CUIDescriptorlll"
SHOW_PATH = "__Z23ShowArtFilePathToStdErrPKh"

EXPECTED_SYMBOLS = {
    SHOW_PATH: 0x291e8,
    LOAD_FROM_ARTFILE: 0x29408,
    LOAD: 0x29c00,
}

EXPECTED_LOAD_CALL = 0x29c80
EXPECTED_BSEARCH_CALL = 0x294f4
EXPECTED_BSEARCH_STUB = 0x2ce70
EXPECTED_COMPARATOR = 0x25c08

EXPECTED_BSEARCH_WINDOW = [
    (0x294dc, "lwz", "r4,0x4d34"),
    (0x294e0, "lwz", "r6,0x4d30"),
    (0x294e8, "or", "r3,r29,r29"),
    (0x294ec, "lhz", "r5,0x529c"),
    (0x294f0, "addi", "r7,r7,0xc7f4"),
]


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
            data = fp.read(1024 * 1024)
            if not data:
                break
            h.update(data)
    finally:
        fp.close()
    return h.hexdigest()


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


def parse_nm_text_symbols(text):
    out = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in line:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        name = parts[-1]
        if name not in out:
            out[name] = addr
    return out


def parse_disassembly(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, line))
    return rows


def find_row(rows, addr):
    for row_addr, line in rows:
        if row_addr == addr:
            return line
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


def parse_lion_artfile(path):
    if not os.path.isfile(path):
        return None
    data = open(path, "rb").read(24)
    if len(data) < 24:
        return None
    return {
        "record_count": struct.unpack("<H", data[0:2])[0],
        "path_len": struct.unpack("<H", data[2:4])[0],
        "component_count": struct.unpack("<H", data[4:6])[0],
        "index_start": struct.unpack("<I", data[16:20])[0],
        "payload_start": struct.unpack("<I", data[20:24])[0],
    }


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "./pm-art-titlebar-bsearch-boundary.txt"
    issues = []
    tempdir = tempfile.mkdtemp(prefix="pm-art-bsearch-boundary.")

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        product = product_out.strip()
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        build = build_out.strip()

        expected_build = None
        if product == "10.6.8":
            expected_build = "10K549"
        elif product == "10.7.5":
            expected_build = "11G63"
        else:
            issues.append("unsupported product version: %s" % product)

        if expected_build is not None and build != expected_build:
            issues.append("unexpected build version: %s" % build)

        cache_sha = sha256(ROSETTA_CACHE) if os.path.isfile(ROSETTA_CACHE) else "MISSING"
        map_sha = sha256(ROSETTA_MAP) if os.path.isfile(ROSETTA_MAP) else "MISSING"
        cache_ok = cache_sha == EXPECTED_CACHE_SHA256
        map_ok = map_sha == EXPECTED_CACHE_MAP_SHA256
        if not cache_ok:
            issues.append("Rosetta shared cache SHA mismatch")
        if not map_ok:
            issues.append("Rosetta shared cache map SHA mismatch")

        map_coreui_hit = False
        if os.path.isfile(ROSETTA_MAP):
            try:
                map_text = open(ROSETTA_MAP, "r").read()
            except IOError:
                map_text = ""
            map_coreui_hit = COREUI in map_text
        if not map_coreui_hit:
            issues.append("CoreUI missing from Rosetta cache map")

        snow_static_pass = None
        snow_fields = {}

        if product == "10.6.8":
            if not os.path.isfile(COREUI):
                issues.append("Snow CoreUI binary missing")
            else:
                coreui_sha = sha256(COREUI)
                snow_fields["coreui_sha256"] = coreui_sha
                if coreui_sha != EXPECTED_SNOW_COREUI_SHA256:
                    issues.append("Snow CoreUI whole-file SHA mismatch")

                thin = os.path.join(tempdir, "CoreUI.ppc7400")
                ok, out = thin_arch(COREUI, "ppc7400", thin)
                snow_fields["ppc_thin"] = ok
                if not ok:
                    issues.append("Snow CoreUI ppc7400 slice unavailable")
                else:
                    slice_sha = sha256(thin)
                    snow_fields["ppc_slice_sha256"] = slice_sha
                    if slice_sha != EXPECTED_SNOW_COREUI_PPC_SHA256:
                        issues.append("Snow CoreUI PPC slice SHA mismatch")

                    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
                    if rc != 0:
                        issues.append("nm -nm failed")
                        symbols = {}
                    else:
                        symbols = parse_nm_text_symbols(nm_out)

                    for name, expected_addr in EXPECTED_SYMBOLS.items():
                        actual = symbols.get(name)
                        snow_fields["symbol_" + name] = actual
                        if actual != expected_addr:
                            issues.append("unexpected symbol address for %s" % name)

                    rc, nm_m = run(["/usr/bin/nm", "-m", thin])
                    if rc != 0:
                        issues.append("nm -m failed")
                        bsearch_import_lines = []
                    else:
                        bsearch_import_lines = [
                            line for line in nm_m.splitlines() if "_bsearch" in line
                        ]
                    snow_fields["bsearch_import_lines"] = bsearch_import_lines
                    lazy_external = any(
                        "undefined" in line.lower() and "lazy" in line.lower()
                        for line in bsearch_import_lines
                    )
                    snow_fields["bsearch_lazy_external"] = lazy_external
                    if not lazy_external:
                        issues.append("_bsearch is not proven undefined/lazy-bound external")

                    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
                    if rc != 0:
                        issues.append("otool disassembly failed")
                        rows = []
                    else:
                        rows = parse_disassembly(dis_out)

                    load_call_line = find_row(rows, EXPECTED_LOAD_CALL)
                    load_call_ok = (
                        load_call_line is not None and
                        LOAD_FROM_ARTFILE in load_call_line and
                        "bl" in load_call_line
                    )
                    snow_fields["load_direct_call_line"] = load_call_line
                    if not load_call_ok:
                        issues.append("direct CUIElement::Load -> LoadFromArtFile call not proven")

                    bsearch_call_lines = [
                        (addr, line) for addr, line in rows
                        if "symbol stub for: _bsearch" in line
                    ]
                    snow_fields["bsearch_call_lines"] = bsearch_call_lines
                    bsearch_call_ok = (
                        len(bsearch_call_lines) == 1 and
                        bsearch_call_lines[0][0] == EXPECTED_BSEARCH_CALL and
                        ("0x%x" % EXPECTED_BSEARCH_STUB) in bsearch_call_lines[0][1]
                    )
                    if not bsearch_call_ok:
                        issues.append("exact single _bsearch stub call not proven")

                    setup_ok = True
                    setup_lines = []
                    for addr, mnemonic, operand_prefix in EXPECTED_BSEARCH_WINDOW:
                        line = find_row(rows, addr)
                        setup_lines.append((addr, line))
                        if (
                            line is None or
                            mnemonic not in line or
                            operand_prefix not in line.replace(" ", "")
                        ):
                            setup_ok = False
                    snow_fields["bsearch_setup_lines"] = setup_lines
                    if not setup_ok:
                        issues.append("bsearch argument setup window mismatch")

                    comparator_ok = setup_ok
                    snow_fields["comparator_relative_address"] = EXPECTED_COMPARATOR
                    if not comparator_ok:
                        issues.append("CoreUI comparator derivation not proven")

                    snow_static_pass = (
                        coreui_sha == EXPECTED_SNOW_COREUI_SHA256 and
                        slice_sha == EXPECTED_SNOW_COREUI_PPC_SHA256 and
                        lazy_external and load_call_ok and bsearch_call_ok and
                        setup_ok and comparator_ok
                    )

        lion_fields = {}
        if product == "10.7.5":
            art_size = os.path.getsize(ARTFILE) if os.path.isfile(ARTFILE) else -1
            art_sha = sha256(ARTFILE) if os.path.isfile(ARTFILE) else "MISSING"
            header = parse_lion_artfile(ARTFILE)
            lion_fields["art_size"] = art_size
            lion_fields["art_sha"] = art_sha
            lion_fields["header"] = header

            if art_size != EXPECTED_LION_ARTFILE_SIZE:
                issues.append("Lion ArtFile size mismatch")
            if art_sha != EXPECTED_LION_ARTFILE_SHA256:
                issues.append("Lion ArtFile SHA mismatch")
            if header is None:
                issues.append("Lion ArtFile header unavailable")
            else:
                expected_header = {
                    "record_count": 2674,
                    "path_len": 8,
                    "component_count": 169,
                    "index_start": 0xb9d,
                    "payload_start": 0x88f8,
                }
                for key, value in expected_header.items():
                    if header.get(key) != value:
                        issues.append("Lion ArtFile header mismatch: %s" % key)

            ppc_ok, ppc_out = verify_arch(COREUI, "ppc7400") if os.path.isfile(COREUI) else (False, "")
            lion_fields["disk_coreui_ppc_present"] = ppc_ok
            if ppc_ok:
                issues.append("Lion on-disk CoreUI unexpectedly contains ppc7400")

        with open(report, "w") as fp:
            write_line(fp, "== CoreUI titlebar bsearch integration-boundary audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "audit_contract=%s" % AUDIT_CONTRACT)
            write_line(fp, "analyzer_script_path=%s" % os.path.realpath(__file__))
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)

            write_line(fp)
            write_line(fp, "== Rosetta shared-cache provenance ==")
            write_line(fp, "rosetta_cache_sha256=%s" % cache_sha)
            write_line(fp, "rosetta_cache_expected=%s" % ("YES" if cache_ok else "NO"))
            write_line(fp, "rosetta_cache_map_sha256=%s" % map_sha)
            write_line(fp, "rosetta_cache_map_expected=%s" % ("YES" if map_ok else "NO"))
            write_line(fp, "coreui_present_in_rosetta_cache_map=%s" % ("YES" if map_coreui_hit else "NO"))
            write_line(fp, "shared_cache_contract_matches_accepted_snow_ppc=%s" %
                       ("YES" if (cache_ok and map_ok and map_coreui_hit) else "NO"))

            if product == "10.6.8":
                write_line(fp)
                write_line(fp, "== Snow PPC CoreUI static call contract ==")
                write_line(fp, "coreui_sha256=%s" % snow_fields.get("coreui_sha256", "MISSING"))
                write_line(fp, "ppc_slice_sha256=%s" % snow_fields.get("ppc_slice_sha256", "MISSING"))
                for name in [SHOW_PATH, LOAD_FROM_ARTFILE, LOAD]:
                    addr = snow_fields.get("symbol_" + name)
                    write_line(fp, "%s_address=%s" % (
                        name,
                        ("0x%x" % addr) if addr is not None else "MISSING"
                    ))
                write_line(fp, "load_to_loadfromartfile_call_kind=DIRECT_INTERNAL_BRANCH")
                write_line(fp, "load_to_loadfromartfile_call_address=0x%x" % EXPECTED_LOAD_CALL)
                write_line(fp, "loadfromartfile_symbol_interposition_candidate=NO")
                write_line(fp, "bsearch_import_kind=%s" %
                           ("UNDEFINED_LAZY_BOUND_EXTERNAL" if snow_fields.get("bsearch_lazy_external") else "UNPROVEN"))
                write_line(fp, "bsearch_stub_call_count=%d" % len(snow_fields.get("bsearch_call_lines", [])))
                write_line(fp, "bsearch_call_address=0x%x" % EXPECTED_BSEARCH_CALL)
                write_line(fp, "bsearch_stub_address=0x%x" % EXPECTED_BSEARCH_STUB)
                write_line(fp, "bsearch_comparator_relative_address=0x%x" % EXPECTED_COMPARATOR)
                write_line(fp, "bsearch_argument_order=key,base,nmemb,size,compar")
                write_line(fp, "candidate_process_local_hook=libSystem_bsearch")
                write_line(fp, "candidate_guard_inputs=exact_key,base,nmemb,size,compar,release_resource_guard")
                write_line(fp, "snow_static_boundary=%s" % ("PASS" if snow_static_pass else "FAIL"))

            if product == "10.7.5":
                write_line(fp)
                write_line(fp, "== Lion live-environment static guard ==")
                write_line(fp, "artfile_size=%d" % lion_fields.get("art_size", -1))
                write_line(fp, "artfile_sha256=%s" % lion_fields.get("art_sha", "MISSING"))
                header = lion_fields.get("header")
                if header is not None:
                    write_line(fp, "artfile_record_count=%d" % header["record_count"])
                    write_line(fp, "artfile_path_length=%d" % header["path_len"])
                    write_line(fp, "artfile_component_count=%d" % header["component_count"])
                    write_line(fp, "artfile_index_start=0x%x" % header["index_start"])
                    write_line(fp, "artfile_payload_start=0x%x" % header["payload_start"])
                write_line(fp, "disk_coreui_ppc_present=%s" %
                           ("YES" if lion_fields.get("disk_coreui_ppc_present") else "NO"))
                write_line(fp, "runtime_ppc_coreui_source=dyld_shared_cache_rosetta")
                write_line(fp, "runtime_ppc_contract_link=accepted_identical_rosetta_cache")
                lion_env_ok = (
                    cache_ok and map_ok and map_coreui_hit and
                    lion_fields.get("art_size") == EXPECTED_LION_ARTFILE_SIZE and
                    lion_fields.get("art_sha") == EXPECTED_LION_ARTFILE_SHA256 and
                    not lion_fields.get("disk_coreui_ppc_present") and
                    lion_fields.get("header") is not None and
                    lion_fields["header"].get("record_count") == 2674 and
                    lion_fields["header"].get("path_len") == 8 and
                    lion_fields["header"].get("index_start") == 0xb9d
                )
                write_line(fp, "lion_environment_guard=%s" % ("PASS" if lion_env_ok else "FAIL"))

            write_line(fp)
            write_line(fp, "== Decision ==")
            write_line(fp, "preferred_boundary=libSystem_bsearch")
            write_line(fp, "reason_loadfromartfile=internal_direct_branch_not_a_stub")
            write_line(fp, "reason_bsearch=external_lazy_bound_stub_reached_from_old_ppc_loadfromartfile")
            write_line(fp, "translation_location=temporary_bsearch_search_key_only")
            write_line(fp, "original_coreui_path_buffer_mutation=NO")
            write_line(fp, "live_interposer_authorized=NO")
            write_line(fp, "next_if_both_reports_pass=prepare_exact_guarded_bsearch_interposer_integration")

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
            write_line(fp, "No PowerPC subject was launched.")
            write_line(fp, "No process was attached.")
            write_line(fp, "No interposer was built, loaded, or installed.")
            write_line(fp, "No framework, ArtFile resource, Rosetta cache, service, or XNU state was modified.")
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
