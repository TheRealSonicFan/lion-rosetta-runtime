#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./distributed-notifications-protocol-abi.txt"
ANALYZER_VERSION = "2"

COREFOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
DISTNOTED = "/usr/sbin/distnoted"

SNOW_SERVICE = "com.apple.distributed_notifications.2"
LION_SERVICE = "com.apple.distributed_notifications@Uv3"

SNOW_TARGETS = [
    "___CFXNotificationSendToServer",
    "___CFXNotificationSendToClient",
    "___CFXNotificationReceiveFromServer",
    "___CFXNotificationReceiveFromClient",
    "___CFXNotificationHandleMessage",
    "__CFXNotificationPostNotification",
    "__CFXNotificationPost",
    "__CFXNotificationRegister",
    "__CFXNotificationUnregister",
    "__CFXNotificationSetSuspended",
    "__CFXNotificationResetSessionForTask",
]

LION_TARGETS = [
    "__CFXNotificationRegisterObserver",
    "__CFXNotificationPost",
    "__CFXNotificationRemoveObservers",
    "__CFXNotificationSetSuspended",
    "__CFXNotificationResetSessionForTask",
    "___CFXNotificationCenterCreate",
    "___CFXNotificationCenterSetupConnection",
    "_____CFXNotificationCenterSetupConnection_block_invoke_1",
    "___CFXNotificationPostToken",
    "_____CFXNotificationPostToken_block_invoke_1",
]

SNOW_PROTOCOL_VALUES = [
    SNOW_SERVICE,
    "message_type",
    "post",
    "name",
    "object",
    "userinfo",
    "counter",
    "entry",
    "ping",
    "pong",
    "client",
    "sessionid",
    "immediately",
    "sux",
    "behavior",
    "entries",
    "state",
    "register",
    "unregister",
    "suspend",
    "session_reset",
]

LION_PROTOCOL_VALUES = [
    LION_SERVICE,
    "method",
    "version",
    "post",
    "post_all",
    "options",
    "token",
    "tokens",
    "name",
    "object",
    "userinfo",
    "register",
    "unregister",
    "suspend",
    "unsuspend",
    "post_token",
    "ping",
    "registrations",
]

XPC_CALL_RE = re.compile(
    r"symbol stub for: (_xpc_dictionary_(?:set|get)_[A-Za-z0-9_]+|"
    r"_xpc_array_[A-Za-z0-9_]+|"
    r"_xpc_connection_send_message(?:_with_reply)?|"
    r"_xpc_connection_get_remote_connection)"
)

CFDICTIONARY_CREATE_RE = re.compile(r"symbol stub for: _CFDictionaryCreate\b")
CFDICTIONARY_SET_RE = re.compile(r"symbol stub for: _CFDictionarySetValue\b")


def run(cmd):
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.communicate()[0]
    except OSError as exc:
        return 127, "exec_failed: %s" % exc
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def line(fp, value=""):
    fp.write(value)
    fp.write("\n")


def sha256(path):
    rc, out = run(["/usr/bin/shasum", "-a", "256", path])
    if rc != 0 or not out.strip():
        return "ERROR"
    return out.split()[0]


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


def signed16(value):
    value &= 0xffff
    if value & 0x8000:
        return value - 0x10000
    return value


def signed32(value):
    value &= 0xffffffff
    if value & 0x80000000:
        return value - 0x100000000
    return value


def parse_nm_text_symbol_name(raw):
    marker = "(__TEXT,__text)"
    if marker not in raw:
        return None
    tail = raw.split(marker, 1)[1].strip()
    prefixes = [
        "non-external (was a private external) ",
        "non-external ",
        "external ",
    ]
    for prefix in prefixes:
        if tail.startswith(prefix):
            return tail[len(prefix):].strip()
    return tail if tail else None


def parse_text_symbols(text):
    ordered = []
    by_name = {}
    for raw in text.splitlines():
        parts = raw.split()
        if len(parts) < 2 or "(__TEXT,__text)" not in raw:
            continue
        addr = parse_hex_token(parts[0])
        name = parse_nm_text_symbol_name(raw)
        if addr is None or not name:
            continue
        ordered.append((addr, name))
        by_name.setdefault(name, []).append(addr)
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for raw in text.splitlines():
        parts = raw.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is not None:
            rows.append((addr, raw))
    return rows


def next_symbol(ordered, start):
    for addr, name in ordered:
        if addr > start:
            return addr
    return None


def window_rows(rows, ordered, start, max_bytes=0x9000):
    end = start + max_bytes
    nxt = next_symbol(ordered, start)
    if nxt is not None:
        end = min(end, nxt)
    result = []
    for addr, raw in rows:
        if addr < start:
            continue
        if addr >= end:
            break
        result.append((addr, raw))
    return result


def parse_sections(path):
    rc, out = run(["/usr/bin/otool", "-l", path])
    sections = {}
    if rc != 0:
        return sections

    current = None
    for raw in out.splitlines():
        s = raw.strip()
        if s.startswith("Load command "):
            if current and current.get("sectname") and current.get("segname"):
                sections[(current["segname"], current["sectname"])] = current
            current = None
            continue
        if s == "Section":
            if current and current.get("sectname") and current.get("segname"):
                sections[(current["segname"], current["sectname"])] = current
            current = {}
            continue
        if current is None:
            continue
        parts = s.split(None, 1)
        if len(parts) != 2:
            continue
        key, value = parts
        if key in ("sectname", "segname"):
            current[key] = value.strip()
        elif key in ("addr", "size"):
            try:
                current[key] = int(value.strip(), 0)
            except ValueError:
                pass
        elif key == "offset":
            try:
                current[key] = int(value.strip(), 0)
            except ValueError:
                try:
                    current[key] = int(value.strip())
                except ValueError:
                    pass

    if current and current.get("sectname") and current.get("segname"):
        sections[(current["segname"], current["sectname"])] = current
    return sections


def read_section(path, sections, segname, sectname):
    info = sections.get((segname, sectname))
    if not info:
        return None, None
    for key in ("addr", "size", "offset"):
        if key not in info:
            return None, None
    try:
        f = open(path, "rb")
        try:
            f.seek(info["offset"])
            blob = f.read(info["size"])
        finally:
            f.close()
    except IOError:
        return None, None
    return info, blob


def decode_bytes(raw):
    if isinstance(raw, str):
        return raw
    return raw.decode("utf-8", "replace")


def make_cstring_map(path, sections):
    info, blob = read_section(path, sections, "__TEXT", "__cstring")
    result = {}
    if info is None or blob is None:
        return result
    zero = b"\x00" if not isinstance(blob, str) else "\x00"
    pos = 0
    while pos < len(blob):
        end = blob.find(zero, pos)
        if end < 0:
            end = len(blob)
        raw = blob[pos:end]
        if raw:
            result[info["addr"] + pos] = decode_bytes(raw)
        pos = end + 1
    return result


def make_cfstring_map(path, sections, arch, cstrings):
    info, blob = read_section(path, sections, "__DATA", "__cfstring")
    result = {}
    if info is None or blob is None:
        return result
    endian = ">" if arch.startswith("ppc") else "<"
    entry_size = 16
    off = 0
    while off + entry_size <= len(blob):
        chunk = blob[off:off + entry_size]
        try:
            words = struct.unpack(endian + "IIII", chunk)
        except Exception:
            off += entry_size
            continue
        value = None
        for word in words:
            if word in cstrings:
                value = cstrings[word]
                break
        if value is not None:
            result[info["addr"] + off] = value
        off += entry_size
    return result


def constant_at(addr, cstrings, cfstrings):
    if addr in cstrings:
        return ("cstring", cstrings[addr])
    if addr in cfstrings:
        return ("cfstring", cfstrings[addr])
    return None


def parse_i386_mem(operand):
    # Handles the simple EBP/ESP slots used for saved PIC bases and locals.
    m = re.match(r"^([+-]?(?:0x[0-9a-fA-F]+|\d+))?\(%(ebp|esp)\)$", operand)
    if not m:
        return None
    disp_text = m.group(1)
    base = m.group(2)
    if disp_text is None or disp_text == "":
        disp = 0
    else:
        try:
            if disp_text.startswith("-0x"):
                disp = -int(disp_text[3:], 16)
            elif disp_text.startswith("+0x"):
                disp = int(disp_text[3:], 16)
            else:
                disp = int(disp_text, 0)
        except ValueError:
            return None
    return (base, disp)


def resolve_i386(rows, cstrings, cfstrings):
    refs = []
    regs = {}
    slots = {}
    pending_call_target = None

    for addr, raw in rows:
        asm = raw.split("\t", 1)[1] if "\t" in raw else raw
        asm = asm.strip()

        m = re.search(r"\bcalll\s+0x([0-9a-fA-F]+)", asm)
        if m:
            call_target = int(m.group(1), 16)
            if call_target == addr + 5:
                pending_call_target = call_target
            else:
                pending_call_target = None
                regs.pop("eax", None)
                regs.pop("ecx", None)
                regs.pop("edx", None)

        m = re.match(r"popl\s+%(e[a-z]{2})$", asm)
        if m and pending_call_target is not None:
            regs[m.group(1)] = pending_call_target
            pending_call_target = None
            continue

        m = re.match(r"movl\s+%(e[a-z]{2}),%(e[a-z]{2})$", asm)
        if m:
            src, dst = m.group(1), m.group(2)
            if src in regs:
                regs[dst] = regs[src]
            else:
                regs.pop(dst, None)
            continue

        m = re.match(r"movl\s+%(e[a-z]{2}),([^,]+)$", asm)
        if m:
            src = m.group(1)
            slot = parse_i386_mem(m.group(2).strip())
            if slot:
                if src in regs:
                    slots[slot] = regs[src]
                else:
                    slots.pop(slot, None)
            continue

        m = re.match(r"movl\s+([^,]+),%(e[a-z]{2})$", asm)
        if m:
            slot = parse_i386_mem(m.group(1).strip())
            dst = m.group(2)
            if slot:
                if slot in slots:
                    regs[dst] = slots[slot]
                else:
                    regs.pop(dst, None)
                continue

        m = re.match(r"leal\s+0x([0-9a-fA-F]+)\(%(e[a-z]{2})\),%(e[a-z]{2})$", asm)
        if m:
            disp = signed32(int(m.group(1), 16))
            src, dst = m.group(2), m.group(3)
            if src in regs:
                value = (regs[src] + disp) & 0xffffffff
                regs[dst] = value
                hit = constant_at(value, cstrings, cfstrings)
                if hit:
                    refs.append((addr, raw, value, hit[0], hit[1]))
            else:
                regs.pop(dst, None)
            continue

        m = re.match(r"leal\s+(-0x[0-9a-fA-F]+)\(%(e[a-z]{2})\),%(e[a-z]{2})$", asm)
        if m:
            disp = -int(m.group(1)[3:], 16)
            src, dst = m.group(2), m.group(3)
            if src in regs:
                value = (regs[src] + disp) & 0xffffffff
                regs[dst] = value
                hit = constant_at(value, cstrings, cfstrings)
                if hit:
                    refs.append((addr, raw, value, hit[0], hit[1]))
            else:
                regs.pop(dst, None)
            continue

        m = re.match(r"movl\s+\$0x([0-9a-fA-F]+),%(e[a-z]{2})$", asm)
        if m:
            value = int(m.group(1), 16) & 0xffffffff
            dst = m.group(2)
            regs[dst] = value
            hit = constant_at(value, cstrings, cfstrings)
            if hit:
                refs.append((addr, raw, value, hit[0], hit[1]))
            continue

        # Arithmetic destroys tracked address identity unless it is a no-op copy
        # already handled above.
        m = re.search(r"%(e[a-z]{2})\s*$", asm)
        if m and re.match(r"(?:addl|subl|xorl|andl|orl|shll|shrl|imull)\b", asm):
            regs.pop(m.group(1), None)

        if re.search(r"\bret\b", asm):
            regs = {}
            slots = {}
            pending_call_target = None

    return refs


def resolve_ppc(rows, cstrings, cfstrings):
    refs = []
    regs = {}
    slots = {}
    lr_value = None

    for addr, raw in rows:
        asm = raw.split("\t", 1)[1] if "\t" in raw else raw
        asm = asm.strip()

        m = re.search(r"\bbcl\s+[^,]+,[^,]+,0x([0-9a-fA-F]+)", asm)
        if m:
            lr_value = int(m.group(1), 16)

        m = re.match(r"mfspr\s+(r\d+),lr$", asm)
        if m and lr_value is not None:
            regs[m.group(1)] = lr_value
            continue

        m = re.match(r"or\s+(r\d+),(r\d+),\2$", asm)
        if m:
            dst, src = m.group(1), m.group(2)
            if src in regs:
                regs[dst] = regs[src]
            else:
                regs.pop(dst, None)
            continue

        m = re.match(r"addis\s+(r\d+),(r\d+),0x([0-9a-fA-F]+)$", asm)
        if m:
            dst, src = m.group(1), m.group(2)
            if src in regs:
                regs[dst] = (regs[src] + (signed16(int(m.group(3), 16)) << 16)) & 0xffffffff
            else:
                regs.pop(dst, None)
            continue

        m = re.match(r"addi\s+(r\d+),(r\d+),0x([0-9a-fA-F]+)$", asm)
        if m:
            dst, src = m.group(1), m.group(2)
            if src in regs:
                value = (regs[src] + signed16(int(m.group(3), 16))) & 0xffffffff
                regs[dst] = value
                hit = constant_at(value, cstrings, cfstrings)
                if hit:
                    refs.append((addr, raw, value, hit[0], hit[1]))
            else:
                regs.pop(dst, None)
            continue

        # Preserve simple stack spills/reloads used for PIC bases.
        m = re.match(r"stw\s+(r\d+),([+-]?(?:0x[0-9a-fA-F]+|\d+))\(r1\)$", asm)
        if m:
            src = m.group(1)
            try:
                disp = int(m.group(2), 0)
            except ValueError:
                disp = None
            if disp is not None:
                if src in regs:
                    slots[disp] = regs[src]
                else:
                    slots.pop(disp, None)
            continue

        m = re.match(r"lwz\s+(r\d+),([+-]?(?:0x[0-9a-fA-F]+|\d+))\(r1\)$", asm)
        if m:
            dst = m.group(1)
            try:
                disp = int(m.group(2), 0)
            except ValueError:
                disp = None
            if disp is not None and disp in slots:
                regs[dst] = slots[disp]
            else:
                regs.pop(dst, None)
            continue

        if re.search(r"\bblr\b", asm):
            regs = {}
            slots = {}
            lr_value = None

    return refs


def resolve_constants(rows, arch, cstrings, cfstrings):
    if arch.startswith("ppc"):
        return resolve_ppc(rows, cstrings, cfstrings)
    return resolve_i386(rows, cstrings, cfstrings)


def refs_by_addr(refs):
    result = {}
    for addr, raw, value_addr, kind, value in refs:
        result.setdefault(addr, []).append((value_addr, kind, value))
    return result


def emit_protocol_inventory(fp, cstrings, cfstrings, values):
    wanted = {}
    for value in values:
        wanted[value] = True

    found = {}
    rows = []
    for addr, value in cstrings.items():
        if value in wanted:
            rows.append((addr, "cstring", value))
            found[value] = True
    for addr, value in cfstrings.items():
        if value in wanted:
            rows.append((addr, "cfstring", value))
            found[value] = True
    rows.sort()

    line(fp)
    line(fp, "-- exact protocol constant inventory --")
    for addr, kind, value in rows:
        line(fp, "0x%x %s %s" % (addr, kind, value))
    for value in values:
        line(fp, "protocol_constant[%s]=%s" %
             (value, "YES" if found.get(value, False) else "NO"))
    return found


def emit_context(fp, window, center_index, refmap, before, after, tag):
    lo = max(0, center_index - before)
    hi = min(len(window), center_index + after + 1)
    line(fp, "context=%s instruction_index=%d" % (tag, center_index))
    for i in range(lo, hi):
        addr, raw = window[i]
        line(fp, raw)
        for value_addr, kind, value in refmap.get(addr, []):
            line(fp, "resolved_constant address=0x%x kind=%s value=%s" %
                 (value_addr, kind, value))


def emit_target(fp, name, addresses, rows, ordered, arch, cstrings, cfstrings):
    line(fp)
    line(fp, "-- exact target: %s count=%d --" % (name, len(addresses)))
    for start in sorted(addresses):
        window = window_rows(rows, ordered, start)
        line(fp, "symbol_address=0x%x" % start)
        line(fp, "instruction_lines=%d" % len(window))
        refs = resolve_constants(window, arch, cstrings, cfstrings)
        refmap = refs_by_addr(refs)

        line(fp, "-- complete symbol window --")
        for addr, raw in window:
            line(fp, raw)
            for value_addr, kind, value in refmap.get(addr, []):
                line(fp, "resolved_constant address=0x%x kind=%s value=%s" %
                     (value_addr, kind, value))

        line(fp, "-- dictionary construction contexts --")
        context_count = 0
        for i in range(len(window)):
            raw = window[i][1]
            if CFDICTIONARY_CREATE_RE.search(raw) or CFDICTIONARY_SET_RE.search(raw):
                emit_context(fp, window, i, refmap, 96, 20,
                             "CFDictionary-construction")
                context_count += 1
        line(fp, "dictionary_context_count=%d" % context_count)

        line(fp, "-- XPC set/get/send contexts --")
        xpc_count = 0
        for i in range(len(window)):
            raw = window[i][1]
            m = XPC_CALL_RE.search(raw)
            if m:
                emit_context(fp, window, i, refmap, 28, 12,
                             "XPC:%s" % m.group(1))
                xpc_count += 1
        line(fp, "xpc_context_count=%d" % xpc_count)


def mach_header_observations(fp, by_name, rows, ordered):
    line(fp)
    line(fp, "== Snow legacy Mach envelope ABI ==")
    line(fp, "mach_header_field_offset_0x00=msgh_bits")
    line(fp, "mach_header_field_offset_0x04=msgh_size")
    line(fp, "mach_header_field_offset_0x08=msgh_remote_port")
    line(fp, "mach_header_field_offset_0x0c=msgh_local_port")
    line(fp, "mach_header_field_offset_0x10=msgh_reserved")
    line(fp, "mach_header_field_offset_0x14=msgh_id")
    line(fp, "legacy_payload_length_offset=0x1c")
    line(fp, "legacy_payload_offset=0x20")

    def joined_for(name):
        addrs = by_name.get(name, [])
        if not addrs:
            return ""
        return "\n".join([raw for addr, raw in window_rows(rows, ordered, addrs[0])])

    c2s = joined_for("___CFXNotificationSendToServer")
    s2c = joined_for("___CFXNotificationSendToClient")

    def find_li_store(text, immediate, offset):
        rows_local = text.splitlines()
        if offset == "0x0":
            offset_pattern = r"(?:__mh_dylib_header|0x0|0)"
        else:
            offset_pattern = re.escape(offset)
        for i in range(len(rows_local)):
            m = re.search(r"\bli\s+(r\d+),%s\b" % re.escape(immediate),
                          rows_local[i])
            if not m:
                continue
            reg = m.group(1)
            for j in range(i + 1, min(len(rows_local), i + 14)):
                pattern = r"\bstw\s+%s,%s\(r\d+\)" % (
                    re.escape(reg), offset_pattern)
                if re.search(pattern, rows_local[j]):
                    return (rows_local[i], rows_local[j])
        return None

    c2s_bits_match = find_li_store(c2s, "0x1413", "0x0")
    c2s_id4_match = find_li_store(c2s, "0x4", "0x14")
    s2c_bits_match = find_li_store(s2c, "0x13", "0x0")
    s2c_id4_match = find_li_store(s2c, "0x4", "0x14")

    c2s_bits = c2s_bits_match is not None
    c2s_id4 = c2s_id4_match is not None
    s2c_bits = s2c_bits_match is not None
    s2c_id4 = s2c_id4_match is not None
    c2s_len = re.search(r"stw\s+r\d+,0x1c\(r\d+\)", c2s) is not None
    s2c_len = re.search(r"stw\s+r\d+,0x1c\(r\d+\)", s2c) is not None

    line(fp, "client_to_server_msgh_bits_0x1413=%s" % ("YES" if c2s_bits else "NO"))
    if c2s_bits_match:
        line(fp, "client_to_server_msgh_bits_load=%s" % c2s_bits_match[0])
        line(fp, "client_to_server_msgh_bits_store=%s" % c2s_bits_match[1])
    line(fp, "client_to_server_msgh_id_4_at_0x14=%s" % ("YES" if c2s_id4 else "NO"))
    if c2s_id4_match:
        line(fp, "client_to_server_msgh_id_load=%s" % c2s_id4_match[0])
        line(fp, "client_to_server_msgh_id_store=%s" % c2s_id4_match[1])
    line(fp, "client_to_server_payload_length_at_0x1c=%s" % ("YES" if c2s_len else "NO"))
    line(fp, "server_to_client_msgh_bits_0x13=%s" % ("YES" if s2c_bits else "NO"))
    if s2c_bits_match:
        line(fp, "server_to_client_msgh_bits_load=%s" % s2c_bits_match[0])
        line(fp, "server_to_client_msgh_bits_store=%s" % s2c_bits_match[1])
    line(fp, "server_to_client_msgh_id_4_at_0x14=%s" % ("YES" if s2c_id4 else "NO"))
    if s2c_id4_match:
        line(fp, "server_to_client_msgh_id_load=%s" % s2c_id4_match[0])
        line(fp, "server_to_client_msgh_id_store=%s" % s2c_id4_match[1])
    line(fp, "server_to_client_payload_length_at_0x1c=%s" % ("YES" if s2c_len else "NO"))
    line(fp, "corrected_interpretation=0x1413_is_msgh_bits_not_msgh_id")

    return {
        "c2s_bits": c2s_bits,
        "c2s_id4": c2s_id4,
        "c2s_len": c2s_len,
        "s2c_bits": s2c_bits,
        "s2c_id4": s2c_id4,
        "s2c_len": s2c_len,
    }


def analyze_cf_slice(fp, source_path, arch, tempdir, targets, protocol_values,
                     label):
    thin = os.path.join(tempdir, "%s.%s" % (label, arch))
    evidence = {}

    line(fp)
    line(fp, "============================================================")
    line(fp, "== %s: %s ==" % (label, arch))
    ok = thin_arch(source_path, arch, thin)
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    evidence["slice"] = ok
    if not ok:
        return evidence

    line(fp, "slice_sha256=%s" % sha256(thin))
    sections = parse_sections(thin)
    cstrings = make_cstring_map(thin, sections)
    cfstrings = make_cfstring_map(thin, sections, arch, cstrings)
    line(fp, "cstring_entry_count=%d" % len(cstrings))
    line(fp, "cfstring_entry_count=%d" % len(cfstrings))
    evidence["cstrings"] = bool(cstrings)
    evidence["cfstrings"] = bool(cfstrings)
    evidence["protocol_constants"] = emit_protocol_inventory(
        fp, cstrings, cfstrings, protocol_values)

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        line(fp, "nm_failed")
        line(fp, nm_out.rstrip())
        return evidence
    ordered, by_name = parse_text_symbols(nm_out)

    line(fp)
    line(fp, "-- target symbol inventory --")
    for target in targets:
        count = len(by_name.get(target, []))
        line(fp, "%s count=%d" % (target, count))
        evidence["target:" + target] = count > 0

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        line(fp, "disassembly_failed")
        line(fp, dis_out.rstrip())
        return evidence
    rows = parse_instructions(dis_out)

    if arch.startswith("ppc") and label == "Snow CoreFoundation":
        envelope = mach_header_observations(fp, by_name, rows, ordered)
        for key, value in envelope.items():
            evidence["envelope:" + key] = value

    for target in targets:
        emit_target(fp, target, by_name.get(target, []), rows, ordered,
                    arch, cstrings, cfstrings)

    return evidence


def analyze_lion_distnoted(fp, source_path, tempdir):
    evidence = {}
    arch = "i386"
    thin = os.path.join(tempdir, "Lion-distnoted.i386")

    line(fp)
    line(fp, "============================================================")
    line(fp, "== Lion distnoted: i386 ==")
    ok = thin_arch(source_path, arch, thin)
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    evidence["slice"] = ok
    if not ok:
        return evidence

    line(fp, "slice_sha256=%s" % sha256(thin))
    sections = parse_sections(thin)
    cstrings = make_cstring_map(thin, sections)
    cfstrings = make_cfstring_map(thin, sections, arch, cstrings)
    evidence["cstrings"] = bool(cstrings)
    evidence["cfstrings"] = bool(cfstrings)
    evidence["protocol_constants"] = emit_protocol_inventory(
        fp, cstrings, cfstrings, LION_PROTOCOL_VALUES)

    line(fp)
    line(fp, "-- complete short cstring inventory --")
    short_rows = []
    for addr, value in cstrings.items():
        if len(value) <= 128:
            short_rows.append((addr, value))
    short_rows.sort()
    for addr, value in short_rows:
        line(fp, "0x%x %s" % (addr, value))

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    imports = []
    if rc == 0:
        for raw in nm_out.splitlines():
            if ("_xpc_" in raw or "_mach_msg" in raw or
                    "bootstrap_look_up" in raw or "_mig_" in raw):
                imports.append(raw)

    line(fp)
    line(fp, "-- transport imports --")
    for raw in imports:
        line(fp, raw)
    joined = "\n".join(imports)
    evidence["xpc_dict"] = "_xpc_dictionary_" in joined
    evidence["xpc_send"] = "_xpc_connection_send_message" in joined
    evidence["mach_msg"] = "_mach_msg" in joined
    evidence["bootstrap"] = "bootstrap_look_up" in joined

    rc, objc = run(["/usr/bin/otool", "-ov", thin])
    line(fp)
    line(fp, "-- Objective-C metadata --")
    if rc == 0:
        for raw in objc.splitlines():
            line(fp, raw)
    else:
        line(fp, "otool_objc_metadata_failed")

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        line(fp, "disassembly_failed")
        return evidence
    rows = parse_instructions(dis_out)
    refs = resolve_i386(rows, cstrings, cfstrings)
    refmap = refs_by_addr(refs)
    dis_lines = dis_out.splitlines()

    line(fp)
    line(fp, "-- all XPC protocol callsite contexts --")
    count = 0
    parsed = []
    for raw in dis_lines:
        parts = raw.split(None, 1)
        if not parts:
            parsed.append((None, raw))
            continue
        parsed.append((parse_hex_token(parts[0]), raw))

    for i in range(len(parsed)):
        addr, raw = parsed[i]
        m = XPC_CALL_RE.search(raw)
        if not m:
            continue
        count += 1
        lo = max(0, i - 36)
        hi = min(len(parsed), i + 17)
        line(fp, "context=XPC:%s source_line=%d" % (m.group(1), i + 1))
        for j in range(lo, hi):
            a, text = parsed[j]
            line(fp, text)
            if a is not None:
                for value_addr, kind, value in refmap.get(a, []):
                    line(fp, "resolved_constant address=0x%x kind=%s value=%s" %
                         (value_addr, kind, value))
    line(fp, "xpc_context_count=%d" % count)

    return evidence


def require_protocol_constants(evidence, values, prefix, issues):
    found = evidence.get("protocol_constants", {})
    for value in values:
        if not found.get(value, False):
            issues.append("%s protocol constant missing: %s" % (prefix, value))


def emit_normalized_boundary(fp):
    line(fp)
    line(fp, "== Normalized static translation boundary ==")
    line(fp, "snow_selector_key=message_type")
    line(fp, "snow_operations=post,register,unregister,suspend,session_reset")
    line(fp, "snow_payload_representation=binary property list dictionary")
    line(fp, "snow_client_to_server_msgh_bits=0x1413")
    line(fp, "snow_client_to_server_msgh_id=4")
    line(fp, "snow_server_to_client_msgh_bits=0x13")
    line(fp, "snow_server_to_client_msgh_id=4")
    line(fp, "lion_selector_key=method")
    line(fp, "lion_protocol_version_key=version")
    line(fp, "lion_protocol_version=1")
    line(fp, "lion_operations=post,post_all,register,unregister,suspend,unsuspend,post_token")
    line(fp, "lion_callback_method=post_token")
    line(fp, "candidate_direct_operation_mapping=post->post,register->register,unregister->unregister")
    line(fp, "candidate_callback_mapping=Snow post dictionary <-> Lion post_token requires token semantics")
    line(fp, "unresolved_mapping=legacy session_reset/suspend/behavior/state/entries/sux/immediately versus Lion options/tokens/suspend/unsuspend")
    line(fp, "mapping_status=STATIC_CONTEXT_ONLY_DO_NOT_IMPLEMENT_YET")


def validate_snow(ppc, i386, issues):
    for label, evidence in (("Snow PPC", ppc), ("Snow i386", i386)):
        if not evidence.get("slice", False):
            issues.append("%s CoreFoundation slice missing" % label)
        if not evidence.get("cstrings", False):
            issues.append("%s __cstring map missing" % label)
        if not evidence.get("cfstrings", False):
            issues.append("%s __cfstring map missing" % label)
        for target in SNOW_TARGETS:
            if not evidence.get("target:" + target, False):
                issues.append("%s target missing: %s" % (label, target))
        require_protocol_constants(
            evidence,
            [SNOW_SERVICE, "message_type", "post", "name", "object",
             "userinfo", "sessionid", "register", "unregister",
             "suspend", "session_reset"],
            label,
            issues)

    for key in ("c2s_bits", "c2s_id4", "c2s_len",
                "s2c_bits", "s2c_id4", "s2c_len"):
        if not ppc.get("envelope:" + key, False):
            issues.append("Snow PPC Mach-envelope observation missing: %s" % key)


def validate_lion(cf, distnoted, issues):
    if not cf.get("slice", False):
        issues.append("Lion CoreFoundation i386 slice missing")
    for target in LION_TARGETS:
        if not cf.get("target:" + target, False):
            issues.append("Lion CoreFoundation target missing: %s" % target)
    require_protocol_constants(
        cf,
        [LION_SERVICE, "method", "version", "post", "options", "token",
         "name", "object", "userinfo", "register", "unregister",
         "tokens", "post_token"],
        "Lion CoreFoundation",
        issues)

    if not distnoted.get("slice", False):
        issues.append("Lion distnoted i386 slice missing")
    if not distnoted.get("xpc_dict", False):
        issues.append("Lion distnoted XPC dictionary imports missing")
    if not distnoted.get("xpc_send", False):
        issues.append("Lion distnoted XPC send import missing")
    require_protocol_constants(
        distnoted,
        [LION_SERVICE, "method", "version", "post", "options", "token",
         "name", "object", "userinfo", "register", "unregister",
         "tokens", "suspend", "unsuspend", "post_token"],
        "Lion distnoted",
        issues)


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="distnotify-abi.")
    issues = []

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        with open(report, "w") as fp:
            line(fp, "== Distributed notifications protocol ABI audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "selected_lion_service=%s" % LION_SERVICE)
            line(fp, "protocol_boundary=field semantics before standalone bridge")
            line(fp, "snow_header_correction=0x1413_is_msgh_bits_not_msgh_id")

            if not os.path.isfile(COREFOUNDATION):
                issues.append("CoreFoundation binary missing")
                ppc = {}
                i386 = {}
                lion_cf = {}
            elif product == "10.6.8":
                line(fp, "corefoundation_sha256=%s" % sha256(COREFOUNDATION))
                ppc = analyze_cf_slice(
                    fp, COREFOUNDATION, "ppc7400", tempdir,
                    SNOW_TARGETS, SNOW_PROTOCOL_VALUES,
                    "Snow CoreFoundation")
                i386 = analyze_cf_slice(
                    fp, COREFOUNDATION, "i386", tempdir,
                    SNOW_TARGETS, SNOW_PROTOCOL_VALUES,
                    "Snow CoreFoundation")
                lion_cf = {}
                validate_snow(ppc, i386, issues)
            elif product == "10.7.5":
                line(fp, "corefoundation_sha256=%s" % sha256(COREFOUNDATION))
                lion_cf = analyze_cf_slice(
                    fp, COREFOUNDATION, "i386", tempdir,
                    LION_TARGETS, LION_PROTOCOL_VALUES,
                    "Lion CoreFoundation")
                ppc = {}
                i386 = {}
            else:
                ppc = {}
                i386 = {}
                lion_cf = {}
                issues.append("unsupported OS baseline: %s" % product)

            if product == "10.7.5":
                if not os.path.isfile(DISTNOTED):
                    distnoted = {}
                    issues.append("Lion distnoted binary missing")
                else:
                    line(fp, "distnoted_sha256=%s" % sha256(DISTNOTED))
                    distnoted = analyze_lion_distnoted(
                        fp, DISTNOTED, tempdir)
                validate_lion(lion_cf, distnoted, issues)
                line(fp)
                line(fp, "lion_distnoted_imports_mach_msg=%s" %
                     ("YES" if distnoted.get("mach_msg", False) else "NO"))
                line(fp, "lion_distnoted_imports_bootstrap_lookup=%s" %
                     ("YES" if distnoted.get("bootstrap", False) else "NO"))

            emit_normalized_boundary(fp)

            line(fp)
            line(fp, "== Audit validation ==")
            if issues:
                for issue in issues:
                    line(fp, "validation_issue=%s" % issue)
                line(fp, "RESULT: FAIL")
            else:
                line(fp, "RESULT: PASS")

            line(fp)
            line(fp, "== Audit integrity ==")
            line(fp, "No PowerPC application was launched by this audit.")
            line(fp, "No notification-center API was called dynamically.")
            line(fp, "No bootstrap lookup, Mach request, MIG request, or XPC request was issued.")
            line(fp, "No distributed notification was registered, posted, removed, or delivered intentionally.")
            line(fp, "No launchd or distnoted process was started, stopped, restarted, signaled, or modified.")
            line(fp, "No framework, executable, launchd plist, Rosetta component, cache, or kernel was modified.")
            line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

        print("Created: %s" % report)
        print("No PowerPC application was launched and no system state was modified.")
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
