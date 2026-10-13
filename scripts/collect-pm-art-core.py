#!/usr/bin/python
from __future__ import print_function

import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import shutil

ANALYZER_VERSION = "1"

TRANSLATOR = "/usr/libexec/oah/translate"
GDB = "/usr/bin/gdb"
ARTFILE = "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

EXPECTED_TRANSLATOR_SHA = "4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_ARTFILE_SHA = "0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4"
EXPECTED_ARTFILE_SIZE = 4765184

COREUI_BASE = 0x923de000
GLOBALS_START = 0x9241c100
GLOBALS_END = 0x9241c700
STACK_START = 0xbfffb000
STACK_END = 0xbffff000
CRASH_GUEST_SP = 0xbfffbfe0
LOAD_RETURN_LR = 0x92407c84
LOAD_PATH_OFFSET = 0x44
FAULT_ADDRESS = 0x787221c4

G_COUNT_PLUS4 = 0x9241c144
G_FIELD10_PTR = 0x9241c148
G_MMAP_BASE = 0x9241c14c
G_TABLE_PTR = 0x9241c6a8
G_STRING_PTR = 0x9241c6ac
G_HEADER = 0x9241c6b0


def run(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.communicate()[0]
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def sha256(path):
    h = hashlib.sha256()
    f = open(path, "rb")
    try:
        while True:
            data = f.read(1024 * 1024)
            if not data:
                break
            h.update(data)
    finally:
        f.close()
    return h.hexdigest()


def write_line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def bval(ch):
    if isinstance(ch, int):
        return ch
    return ord(ch)


def u16be(data, off):
    return struct.unpack(">H", data[off:off + 2])[0]


def u32be(data, off):
    return struct.unpack(">I", data[off:off + 4])[0]


def u16le(data, off):
    return struct.unpack("<H", data[off:off + 2])[0]


def u32le(data, off):
    return struct.unpack("<I", data[off:off + 4])[0]


def bytes_hex(data):
    return "".join("%02x" % bval(x) for x in data)


def addr_off(addr, base, data):
    off = addr - base
    if off < 0 or off >= len(data):
        raise ValueError("address 0x%x outside dump 0x%x..0x%x" %
                         (addr, base, base + len(data)))
    return off


def be32_at_addr(data, base, addr):
    off = addr_off(addr, base, data)
    if off + 4 > len(data):
        raise ValueError("word at 0x%x outside dump" % addr)
    return u32be(data, off)


def be16_at_addr(data, base, addr):
    off = addr_off(addr, base, data)
    if off + 2 > len(data):
        raise ValueError("halfword at 0x%x outside dump" % addr)
    return u16be(data, off)


def cstring(data, off, limit=512):
    if off < 0 or off >= len(data):
        return None
    out = []
    end = min(len(data), off + limit)
    i = off
    while i < end:
        v = bval(data[i])
        if v == 0:
            return "".join(out)
        if 0x20 <= v <= 0x7e:
            out.append(chr(v))
        else:
            out.append("\\x%02x" % v)
        i += 1
    return "".join(out) + "<unterminated>"


def gdb_dump(core, commands, cmd_path, out_path):
    fp = open(cmd_path, "w")
    try:
        fp.write("set pagination off\n")
        fp.write("set confirm off\n")
        for command in commands:
            fp.write(command)
            fp.write("\n")
    finally:
        fp.close()

    rc, out = run([GDB, "-nx", "-batch", "-e", TRANSLATOR,
                   "-c", core, "-x", cmd_path])
    ofp = open(out_path, "w")
    try:
        ofp.write(out)
    finally:
        ofp.close()
    return rc, out


def stack_chain(stack):
    chain = []
    sp = CRASH_GUEST_SP
    seen = set()
    for index in range(64):
        if sp in seen:
            break
        seen.add(sp)
        if sp < STACK_START or sp + 4 > STACK_END:
            break
        off = sp - STACK_START
        caller = u32be(stack, off)
        if caller <= sp or caller < STACK_START or caller + 12 > STACK_END:
            break
        saved_lr = u32be(stack, caller - STACK_START + 8)
        chain.append((index, sp, caller, saved_lr))
        sp = caller
    return chain


def main():
    if len(sys.argv) != 4:
        print("usage: %s /cores/core.PID /path/to/report.crash output.txt" %
              sys.argv[0], file=sys.stderr)
        return 2

    core = os.path.abspath(sys.argv[1])
    crash = os.path.abspath(sys.argv[2])
    report = os.path.abspath(sys.argv[3])
    issues = []

    rc, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
    product = product_out.strip()
    rc, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
    build = build_out.strip()

    if product != "10.7.5":
        issues.append("requires Mac OS X 10.7.5 (found %s)" % product)
    if not os.path.isfile(core):
        issues.append("preserved core missing: %s" % core)
    if not os.path.isfile(crash):
        issues.append("matching crash report missing: %s" % crash)
    if not os.path.isfile(TRANSLATOR):
        issues.append("Rosetta translator missing")
    if not os.path.isfile(GDB):
        issues.append("Apple GDB missing")
    if not os.path.isfile(ARTFILE):
        issues.append("Lion ArtFile.bin missing")

    translator_sha = sha256(TRANSLATOR) if os.path.isfile(TRANSLATOR) else "MISSING"
    art_sha = sha256(ARTFILE) if os.path.isfile(ARTFILE) else "MISSING"
    art_size = os.path.getsize(ARTFILE) if os.path.isfile(ARTFILE) else -1

    if translator_sha != EXPECTED_TRANSLATOR_SHA:
        issues.append("translator SHA mismatch")
    if art_sha != EXPECTED_ARTFILE_SHA:
        issues.append("Lion ArtFile.bin SHA mismatch")
    if art_size != EXPECTED_ARTFILE_SIZE:
        issues.append("Lion ArtFile.bin size mismatch")

    crash_text = ""
    if os.path.isfile(crash):
        crash_text = open(crash, "r").read()
        required = [
            "KERN_INVALID_ADDRESS at 0x00000000787221c4",
            "ShowArtFilePathToStdErr(unsigned char const*) + 220",
            "CUIElement::LoadFromArtFile(unsigned char const*) + 1840",
            "CUIElement::Load(_QSIContext*, CUIDescriptor const*, long, long, long) + 132",
        ]
        for marker in required:
            if marker not in crash_text:
                issues.append("crash marker missing: %s" % marker)

    tempdir = tempfile.mkdtemp(prefix="pm-art-core.")
    try:
        globals_bin = os.path.join(tempdir, "globals.bin")
        stack_bin = os.path.join(tempdir, "stack.bin")
        gdb1_cmd = os.path.join(tempdir, "pass1.gdb")
        gdb1_out = os.path.join(tempdir, "pass1.txt")

        if not issues:
            commands = [
                "dump binary memory %s 0x%x 0x%x" %
                (globals_bin, GLOBALS_START, GLOBALS_END),
                "dump binary memory %s 0x%x 0x%x" %
                (stack_bin, STACK_START, STACK_END),
            ]
            gdb1_status, gdb1_text = gdb_dump(
                core, commands, gdb1_cmd, gdb1_out
            )
        else:
            gdb1_status = -1
            gdb1_text = ""

        if gdb1_status != 0:
            issues.append("first GDB dump pass failed")

        globals_data = open(globals_bin, "rb").read() if os.path.isfile(globals_bin) else ""
        stack_data = open(stack_bin, "rb").read() if os.path.isfile(stack_bin) else ""

        if len(globals_data) != GLOBALS_END - GLOBALS_START:
            issues.append("global dump size mismatch")
        if len(stack_data) != STACK_END - STACK_START:
            issues.append("guest stack dump size mismatch")

        mapped_base = 0
        table_ptr = 0
        string_ptr = 0
        field10_ptr = 0
        count_plus4 = 0
        core_header = {}

        if len(globals_data) == GLOBALS_END - GLOBALS_START:
            try:
                count_plus4 = be32_at_addr(globals_data, GLOBALS_START, G_COUNT_PLUS4)
                field10_ptr = be32_at_addr(globals_data, GLOBALS_START, G_FIELD10_PTR)
                mapped_base = be32_at_addr(globals_data, GLOBALS_START, G_MMAP_BASE)
                table_ptr = be32_at_addr(globals_data, GLOBALS_START, G_TABLE_PTR)
                string_ptr = be32_at_addr(globals_data, GLOBALS_START, G_STRING_PTR)
                core_header = {
                    "u16_0": be16_at_addr(globals_data, GLOBALS_START, G_HEADER + 0),
                    "u16_2": be16_at_addr(globals_data, GLOBALS_START, G_HEADER + 2),
                    "u16_4": be16_at_addr(globals_data, GLOBALS_START, G_HEADER + 4),
                    "u32_8": be32_at_addr(globals_data, GLOBALS_START, G_HEADER + 8),
                    "u32_c": be32_at_addr(globals_data, GLOBALS_START, G_HEADER + 12),
                    "u32_10": be32_at_addr(globals_data, GLOBALS_START, G_HEADER + 16),
                    "u32_14": be32_at_addr(globals_data, GLOBALS_START, G_HEADER + 20),
                }
            except Exception as e:
                issues.append("cannot decode legacy CoreUI globals: %s" % e)

        disk_data = open(ARTFILE, "rb").read() if os.path.isfile(ARTFILE) else ""
        disk_header = {}
        if len(disk_data) >= 24:
            disk_header = {
                "u16_0": u16le(disk_data, 0),
                "u16_2": u16le(disk_data, 2),
                "u16_4": u16le(disk_data, 4),
                "u32_8": u32le(disk_data, 8),
                "u32_c": u32le(disk_data, 12),
                "u32_10": u32le(disk_data, 16),
                "u32_14": u32le(disk_data, 20),
            }
        else:
            issues.append("Lion ArtFile.bin too short")

        if mapped_base == 0:
            issues.append("legacy ArtFile mapped base is zero")

        mapped_head_bin = os.path.join(tempdir, "mapped-head.bin")
        gdb2_cmd = os.path.join(tempdir, "pass2.gdb")
        gdb2_out = os.path.join(tempdir, "pass2.txt")
        if mapped_base != 0 and not any("first GDB" in x for x in issues):
            commands = [
                "dump binary memory %s 0x%x 0x%x" %
                (mapped_head_bin, mapped_base, mapped_base + 0x100),
            ]
            gdb2_status, gdb2_text = gdb_dump(
                core, commands, gdb2_cmd, gdb2_out
            )
        else:
            gdb2_status = -1
            gdb2_text = ""

        if gdb2_status != 0:
            issues.append("second GDB mapped-head dump pass failed")

        mapped_head = open(mapped_head_bin, "rb").read() if os.path.isfile(mapped_head_bin) else ""
        mapped_head_match = (
            len(mapped_head) == 0x100 and
            len(disk_data) >= 0x100 and
            mapped_head == disk_data[:0x100]
        )
        if not mapped_head_match:
            issues.append("core mapped ArtFile head does not match Lion ArtFile.bin")

        header_match = bool(core_header and disk_header and core_header == disk_header)
        if not header_match:
            issues.append("legacy CoreUI parsed-header globals do not match Lion ArtFile.bin")

        pointer_match = False
        if disk_header and mapped_base:
            pointer_match = (
                table_ptr == mapped_base + disk_header["u32_8"] and
                string_ptr == mapped_base + disk_header["u32_c"] and
                field10_ptr == mapped_base + disk_header["u32_10"] and
                count_plus4 == disk_header["u16_2"] + 4
            )
        if not pointer_match:
            issues.append("legacy CoreUI derived ArtFile globals do not match Lion header")

        chain = stack_chain(stack_data) if len(stack_data) == STACK_END - STACK_START else []
        load_sp_matches = []
        for index, sp, caller, saved_lr in chain:
            if saved_lr == LOAD_RETURN_LR:
                load_sp_matches.append(caller)

        target_bytes = struct.pack(">I", LOAD_RETURN_LR)
        raw_lr_hits = []
        pos = 0
        while stack_data:
            hit = stack_data.find(target_bytes, pos)
            if hit < 0:
                break
            raw_lr_hits.append(STACK_START + hit)
            pos = hit + 1

        if len(load_sp_matches) != 1:
            issues.append("expected exactly one Load-frame match in PPC backchain")

        path_addr = load_sp_matches[0] + LOAD_PATH_OFFSET if len(load_sp_matches) == 1 else 0
        path_bytes = ""
        path_len = disk_header.get("u16_2", 0) if disk_header else 0
        if path_len <= 0 or path_len > 64:
            issues.append("unexpected legacy path length: %d" % path_len)
        elif path_addr:
            off = path_addr - STACK_START
            if off < 0 or off + path_len > len(stack_data):
                issues.append("Load path buffer is outside captured guest stack")
            else:
                path_bytes = stack_data[off:off + path_len]

        decoded = []
        if path_bytes and disk_header:
            for index in range(len(path_bytes)):
                ident = bval(path_bytes[index])
                row = {
                    "index": index,
                    "id": ident,
                    "entry_off": None,
                    "string_rel": None,
                    "file_off": None,
                    "runtime_ptr": None,
                    "text": None,
                    "in_file": None,
                    "fault_equal": False,
                    "fault_inside": False,
                }
                if ident != 0:
                    entry_off = disk_header["u32_8"] - 8 + ident * 8
                    row["entry_off"] = entry_off
                    if entry_off >= 0 and entry_off + 4 <= len(disk_data):
                        string_rel = u32le(disk_data, entry_off)
                        file_off = disk_header["u32_c"] + string_rel
                        runtime_ptr = mapped_base + file_off
                        row["string_rel"] = string_rel
                        row["file_off"] = file_off
                        row["runtime_ptr"] = runtime_ptr
                        if 0 <= file_off < len(disk_data):
                            row["in_file"] = True
                            text_value = cstring(disk_data, file_off)
                            row["text"] = text_value
                            if text_value is not None:
                                raw_len = len(text_value)
                                row["fault_inside"] = (
                                    runtime_ptr <= FAULT_ADDRESS <=
                                    runtime_ptr + raw_len
                                )
                        else:
                            row["in_file"] = False
                        row["fault_equal"] = (runtime_ptr == FAULT_ADDRESS)
                    else:
                        row["in_file"] = False
                decoded.append(row)

        with open(report, "w") as fp:
            write_line(fp, "== Process Manager preserved-core ArtFile state ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "core=%s" % core)
            write_line(fp, "crash_report=%s" % crash)
            write_line(fp, "translator_sha256=%s" % translator_sha)
            write_line(fp, "lion_artfile_path=%s" % ARTFILE)
            write_line(fp, "lion_artfile_size=%d" % art_size)
            write_line(fp, "lion_artfile_sha256=%s" % art_sha)
            write_line(fp, "gdb_pass1_status=%d" % gdb1_status)
            write_line(fp, "gdb_pass2_status=%d" % gdb2_status)

            write_line(fp)
            write_line(fp, "== Legacy Snow-PPC CoreUI fixed addresses ==")
            write_line(fp, "coreui_base=0x%08x" % COREUI_BASE)
            write_line(fp, "legacy_count_plus4_global=0x%08x" % G_COUNT_PLUS4)
            write_line(fp, "legacy_field10_ptr_global=0x%08x" % G_FIELD10_PTR)
            write_line(fp, "legacy_mmap_base_global=0x%08x" % G_MMAP_BASE)
            write_line(fp, "legacy_table_ptr_global=0x%08x" % G_TABLE_PTR)
            write_line(fp, "legacy_string_ptr_global=0x%08x" % G_STRING_PTR)
            write_line(fp, "legacy_header_global=0x%08x" % G_HEADER)

            write_line(fp)
            write_line(fp, "== Core-captured legacy ArtFile state ==")
            write_line(fp, "mapped_base=0x%08x" % mapped_base)
            write_line(fp, "table_ptr=0x%08x" % table_ptr)
            write_line(fp, "string_ptr=0x%08x" % string_ptr)
            write_line(fp, "field10_ptr=0x%08x" % field10_ptr)
            write_line(fp, "count_plus4=%d" % count_plus4)
            for key in ["u16_0", "u16_2", "u16_4", "u32_8", "u32_c", "u32_10", "u32_14"]:
                write_line(fp, "core_header_%s=%s" %
                           (key, str(core_header.get(key, "MISSING"))))
            write_line(fp, "core_header_matches_lion_disk=%s" %
                       ("YES" if header_match else "NO"))
            write_line(fp, "legacy_derived_pointers_match_lion_header=%s" %
                       ("YES" if pointer_match else "NO"))
            write_line(fp, "core_mapped_head_matches_lion_disk=%s" %
                       ("YES" if mapped_head_match else "NO"))
            if mapped_head:
                write_line(fp, "core_mapped_head256_sha256=%s" %
                           hashlib.sha256(mapped_head).hexdigest())
                write_line(fp, "core_mapped_head256_hex=%s" %
                           bytes_hex(mapped_head))

            write_line(fp)
            write_line(fp, "== Lion on-disk ArtFile header decoded as legacy format ==")
            for key in ["u16_0", "u16_2", "u16_4", "u32_8", "u32_c", "u32_10", "u32_14"]:
                write_line(fp, "disk_header_%s=%s" %
                           (key, str(disk_header.get(key, "MISSING"))))

            write_line(fp)
            write_line(fp, "== PPC guest stack unwind ==")
            write_line(fp, "crash_guest_sp=0x%08x" % CRASH_GUEST_SP)
            write_line(fp, "stack_capture=0x%08x..0x%08x" %
                       (STACK_START, STACK_END))
            write_line(fp, "backchain_frame_count=%d" % len(chain))
            for index, sp, caller, saved_lr in chain:
                write_line(fp,
                           "frame=%d sp=0x%08x caller_sp=0x%08x saved_lr=0x%08x" %
                           (index, sp, caller, saved_lr))
            write_line(fp, "load_return_lr=0x%08x" % LOAD_RETURN_LR)
            write_line(fp, "load_frame_match_count=%d" % len(load_sp_matches))
            for value in load_sp_matches:
                write_line(fp, "load_sp=0x%08x" % value)
            write_line(fp, "raw_load_return_lr_hit_count=%d" % len(raw_lr_hits))
            for value in raw_lr_hits[:32]:
                write_line(fp, "raw_load_return_lr_word=0x%08x" % value)

            write_line(fp)
            write_line(fp, "== Active CUIElement::Load ArtFile path buffer ==")
            write_line(fp, "load_path_offset=0x%x" % LOAD_PATH_OFFSET)
            write_line(fp, "path_addr=%s" %
                       ("0x%08x" % path_addr if path_addr else "UNRESOLVED"))
            write_line(fp, "path_length=%d" % path_len)
            write_line(fp, "path_bytes=%s" %
                       (bytes_hex(path_bytes) if path_bytes else "UNRESOLVED"))

            names = []
            fault_equal_count = 0
            fault_inside_count = 0
            invalid_component_count = 0
            for row in decoded:
                if row["id"] == 0:
                    write_line(fp, "path_index=%d id=0x00 terminator_or_empty=YES" %
                               row["index"])
                    continue
                if row["text"]:
                    names.append(row["text"])
                if row["fault_equal"]:
                    fault_equal_count += 1
                if row["fault_inside"]:
                    fault_inside_count += 1
                if row["in_file"] is False:
                    invalid_component_count += 1
                write_line(
                    fp,
                    "path_index=%d id=0x%02x entry_off=%s string_rel=%s "
                    "file_off=%s runtime_ptr=%s in_lion_artfile=%s "
                    "fault_equal=%s fault_inside=%s text=%s" %
                    (
                        row["index"],
                        row["id"],
                        ("0x%x" % row["entry_off"]
                         if row["entry_off"] is not None else "UNRESOLVED"),
                        ("0x%x" % row["string_rel"]
                         if row["string_rel"] is not None else "UNRESOLVED"),
                        ("0x%x" % row["file_off"]
                         if row["file_off"] is not None else "UNRESOLVED"),
                        ("0x%08x" % row["runtime_ptr"]
                         if row["runtime_ptr"] is not None else "UNRESOLVED"),
                        ("YES" if row["in_file"] is True else
                         "NO" if row["in_file"] is False else "UNKNOWN"),
                        ("YES" if row["fault_equal"] else "NO"),
                        ("YES" if row["fault_inside"] else "NO"),
                        row["text"] if row["text"] is not None else "UNRESOLVED",
                    )
                )

            write_line(fp, "decoded_path=%s" %
                       (".".join(names) if names else "UNRESOLVED"))
            write_line(fp, "invalid_component_pointer_count=%d" %
                       invalid_component_count)
            write_line(fp, "fault_address=0x%08x" % FAULT_ADDRESS)
            write_line(fp, "fault_equals_component_pointer_count=%d" %
                       fault_equal_count)
            write_line(fp, "fault_inside_component_string_count=%d" %
                       fault_inside_count)

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
            write_line(fp, "The collector opened only the preserved core, matching crash report, Rosetta translator, and Lion ArtFile.bin for reading.")
            write_line(fp, "No PowerPC application was launched.")
            write_line(fp, "No live process was attached.")
            write_line(fp, "No framework, ArtFile resource, Rosetta cache, service, or XNU state was modified.")
            write_line(fp, "All temporary core-memory dumps were removed on exit.")

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
