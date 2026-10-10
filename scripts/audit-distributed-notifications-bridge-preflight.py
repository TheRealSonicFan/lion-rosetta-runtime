#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./distributed-notifications-bridge-preflight.txt"
ANALYZER_VERSION = "2"

COREFOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"

LIBRARY_CANDIDATES = [
    ("/usr/lib/libSystem.B.dylib", "libSystem.B"),
    ("/usr/lib/libSystem.dylib", "libSystem"),
    ("/usr/lib/system/libxpc.dylib", "libxpc.system"),
    ("/usr/lib/libxpc.dylib", "libxpc"),
]

SNOW_CLIENT_TARGETS = [
    "_CFNotificationCenterAddObserver",
    "_CFNotificationCenterPostNotificationWithOptions",
    "__CFXNotificationPostNotification",
    "__CFXNotificationRegister",
    "__CFXNotificationUnregister",
]

SNOW_SERVER_TARGETS = [
    "___CFXNotificationReceiveFromClient",
    "___CFXNotificationHandleMessage",
]

LION_TARGETS = [
    "_CFNotificationCenterAddObserver",
    "_CFNotificationCenterPostNotificationWithOptions",
    "__CFXNotificationRegisterObserver",
    "__CFXNotificationPost",
    "___checkDelivImmed",
]

SNOW_PROTOCOL_VALUES = [
    "message_type",
    "post",
    "name",
    "object",
    "userinfo",
    "client",
    "sessionid",
    "immediately",
    "sux",
    "counter",
    "entry",
    "behavior",
    "entries",
    "register",
    "unregister",
]

LION_PROTOCOL_VALUES = [
    "method",
    "version",
    "post",
    "options",
    "token",
    "tokens",
    "name",
    "object",
    "userinfo",
    "register",
    "unregister",
    "post_token",
]


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


def joined(window):
    return "\n".join([raw for addr, raw in window])


def count_ref_value(refs, value):
    count = 0
    for addr, raw, value_addr, kind, found in refs:
        if found == value:
            count += 1
    return count


def inspect_cf_slice(fp, arch, targets, label, tempdir):
    evidence = {}
    thin = os.path.join(tempdir, re.sub(r"[^A-Za-z0-9_.-]", "_", label) + "." + arch)

    line(fp)
    line(fp, "============================================================")
    line(fp, "== %s: %s ==" % (label, arch))

    ok = os.path.isfile(COREFOUNDATION) and thin_arch(COREFOUNDATION, arch, thin)
    line(fp, "thin=%s" % ("YES" if ok else "NO"))
    evidence["slice"] = ok
    if not ok:
        return evidence

    line(fp, "slice_sha256=%s" % sha256(thin))
    sections = parse_sections(thin)
    cstrings = make_cstring_map(thin, sections)
    cfstrings = make_cfstring_map(thin, sections, arch, cstrings)
    evidence["cstrings"] = cstrings
    evidence["cfstrings"] = cfstrings

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    if rc != 0:
        line(fp, "nm_failed")
        return evidence
    ordered, by_name = parse_text_symbols(nm_out)
    evidence["by_name"] = by_name

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        line(fp, "disassembly_failed")
        return evidence
    rows = parse_instructions(dis_out)
    evidence["rows"] = rows
    evidence["ordered"] = ordered
    evidence["thin_path"] = thin

    line(fp, "-- semantic target inventory --")
    windows = {}
    refs_by_target = {}
    for target in targets:
        addrs = sorted(by_name.get(target, []))
        line(fp, "%s count=%d" % (target, len(addrs)))
        evidence["target:" + target] = bool(addrs)
        if not addrs:
            continue
        window = window_rows(rows, ordered, addrs[0])
        refs = resolve_constants(window, arch, cstrings, cfstrings)
        windows[target] = window
        refs_by_target[target] = refs

        line(fp)
        line(fp, "-- exact target: %s --" % target)
        line(fp, "symbol_address=0x%x" % addrs[0])
        line(fp, "instruction_lines=%d" % len(window))
        for addr, raw in window:
            line(fp, raw)
            for raddr, rraw, value_addr, kind, value in refs:
                if raddr == addr and value in (SNOW_PROTOCOL_VALUES + LION_PROTOCOL_VALUES):
                    line(fp, "resolved_protocol_constant address=0x%x kind=%s value=%s" %
                         (value_addr, kind, value))

        line(fp, "-- protocol constant xref counts: %s --" % target)
        values = SNOW_PROTOCOL_VALUES if arch.startswith("ppc") or label.startswith("Snow") else LION_PROTOCOL_VALUES
        for value in values:
            count = count_ref_value(refs, value)
            if count:
                line(fp, "xref[%s]=%d" % (value, count))

    evidence["windows"] = windows
    evidence["refs_by_target"] = refs_by_target
    return evidence


def inspect_library(fp, path, label, tempdir, evidence):
    line(fp)
    line(fp, "== Library capability: %s ==" % label)
    line(fp, "path=%s" % path)
    exists = os.path.exists(path)
    line(fp, "exists=%s" % ("YES" if exists else "NO"))
    if not exists:
        return

    line(fp, "sha256=%s" % sha256(path))
    rc, out = run(["/usr/bin/lipo", "-info", path])
    if rc != 0:
        rc, out = run(["/usr/bin/file", path])
    line(fp, "architecture_info=%s" % out.strip().replace("\n", " | "))

    for arch in ("ppc7400", "i386", "x86_64"):
        present = verify_arch(path, arch)
        evidence[(label, arch, "present")] = present
        line(fp, "arch_%s=%s" % (arch, "YES" if present else "NO"))
        if not present:
            continue

        thin = os.path.join(tempdir, "lib." + label.replace("/", "_") + "." + arch)
        if not thin_arch(path, arch, thin):
            continue

        rc, nm_out = run(["/usr/bin/nm", "-g", thin])
        if rc != 0:
            rc, nm_out = run(["/usr/bin/nm", thin])
        has_create = "_xpc_connection_create" in nm_out
        has_send = (
            "_xpc_connection_send_message" in nm_out or
            "_xpc_connection_send_message_with_reply" in nm_out
        )
        evidence[(label, arch, "xpc_create")] = has_create
        evidence[(label, arch, "xpc_send")] = has_send
        line(fp, "xpc_connection_create_%s=%s" %
             (arch, "YES" if has_create else "NO"))
        line(fp, "xpc_connection_send_%s=%s" %
             (arch, "YES" if has_send else "NO"))


def ppc_callable_xpc_surface(evidence):
    for label in ("libSystem.B", "libSystem", "libxpc.system", "libxpc"):
        if (evidence.get((label, "ppc7400", "present"), False) and
                evidence.get((label, "ppc7400", "xpc_create"), False) and
                evidence.get((label, "ppc7400", "xpc_send"), False)):
            return True
    return False


def check_snow_semantics(ppc, server_i386, fp, issues):
    windows = ppc.get("windows", {})
    add = joined(windows.get("_CFNotificationCenterAddObserver", []))
    post = joined(windows.get("__CFXNotificationPostNotification", []))

    behavior_3_to_8 = (
        re.search(r"cmpwi\s+cr7,r27,0x3", add) is not None and
        re.search(r"li\s+r9,0x8", add) is not None
    )
    behavior_4_to_1 = (
        re.search(r"cmpwi\s+cr7,r27,0x4", add) is not None and
        re.search(r"li\s+r9,0x1", add) is not None
    )
    behavior_1_to_2 = (
        re.search(r"cmpwi\s+cr7,r27,0x1", add) is not None and
        re.search(r"li\s+r9,0x2", add) is not None
    )
    behavior_2_to_4 = re.search(r"li\s+r9,0x4", add) is not None

    post_bit_all = re.search(r"andi\.\s+r0,r24,0x2", post) is not None
    post_bit_immediate = re.search(r"andi\.\s+r0,r24,0x1", post) is not None
    public_tail = joined(windows.get("_CFNotificationCenterPostNotificationWithOptions", []))
    public_pass = (
        "__CFXNotificationPostNotification" in public_tail and
        re.search(r"li\s+r8,(?:__mh_dylib_header|0x0|0)\b", public_tail) is not None
    )

    post_refs = ppc.get("refs_by_target", {}).get("__CFXNotificationPostNotification", [])
    server_refs = server_i386.get("refs_by_target", {}).get("___CFXNotificationReceiveFromClient", [])
    post_sux_refs = count_ref_value(post_refs, "sux")
    server_sux_refs = count_ref_value(server_refs, "sux")

    line(fp)
    line(fp, "== Snow public-API reconstruction semantics ==")
    line(fp, "public_behavior_1_to_legacy_internal_2=%s" %
         ("YES" if behavior_1_to_2 else "NO"))
    line(fp, "public_behavior_2_to_legacy_internal_4=%s" %
         ("YES" if behavior_2_to_4 else "NO"))
    line(fp, "public_behavior_3_to_legacy_internal_8=%s" %
         ("YES" if behavior_3_to_8 else "NO"))
    line(fp, "public_behavior_4_to_legacy_internal_1=%s" %
         ("YES" if behavior_4_to_1 else "NO"))
    line(fp, "legacy_internal_to_public_behavior=1->4,2->1,4->2,8->3")
    line(fp, "public_post_options_passed_to_private_sender=%s" %
         ("YES" if public_pass else "NO"))
    line(fp, "post_option_bit_0_controls_immediately=%s" %
         ("YES" if post_bit_immediate else "NO"))
    line(fp, "post_option_bit_1_controls_session_scope=%s" %
         ("YES" if post_bit_all else "NO"))
    line(fp, "ppc_post_sux_constant_xrefs=%d" % post_sux_refs)
    line(fp, "i386_server_receive_sux_constant_xrefs=%d" % server_sux_refs)
    line(fp, "first_proof_sux_policy=require_false; reject true/unknown")
    line(fp, "first_proof_post_scope=current-session only; reject all-session")
    line(fp, "first_proof_public_post_options=immediately?1:0")

    for name, ok in (
            ("behavior 1->2", behavior_1_to_2),
            ("behavior 2->4", behavior_2_to_4),
            ("behavior 3->8", behavior_3_to_8),
            ("behavior 4->1", behavior_4_to_1),
            ("public post wrapper", public_pass),
            ("post immediate bit", post_bit_immediate),
            ("post all-session bit", post_bit_all)):
        if not ok:
            issues.append("Snow semantic observation missing: %s" % name)


def check_lion_public_routes(lion, fp, issues):
    by_name = lion.get("by_name", {})
    windows = lion.get("windows", {})

    add_addrs = by_name.get("__CFXNotificationRegisterObserver", [])
    post_addrs = by_name.get("__CFXNotificationPost", [])
    add_text = joined(windows.get("_CFNotificationCenterAddObserver", []))
    post_text = joined(windows.get("_CFNotificationCenterPostNotificationWithOptions", []))

    add_route = False
    for addr in add_addrs:
        if ("calll\t0x%08x" % addr) in add_text or ("calll\t0x%x" % addr) in add_text:
            add_route = True
    post_route = False
    for addr in post_addrs:
        if ("calll\t0x%08x" % addr) in post_text or ("calll\t0x%x" % addr) in post_text:
            post_route = True

    check_present = bool(by_name.get("___checkDelivImmed", []))

    line(fp)
    line(fp, "== Lion public-API broker boundary ==")
    line(fp, "public_addobserver_routes_to_native_register=%s" %
         ("YES" if add_route else "NO"))
    line(fp, "public_post_with_options_routes_to_native_post=%s" %
         ("YES" if post_route else "NO"))
    line(fp, "native_checkDelivImmed_present=%s" %
         ("YES" if check_present else "NO"))
    line(fp, "broker_translation_layer=Snow-v2 dictionary -> Lion public CFNotificationCenter API")
    line(fp, "raw_lion_xpc_dictionary_synthesis=NO")
    line(fp, "native_corefoundation_owns_xpc_option_quirks=YES")
    line(fp, "first_proof_operations=register,post_current_session,callback,unregister")
    line(fp, "first_proof_reject=suspend,session_reset,post_all_sessions,sux_true")

    if not add_route:
        issues.append("Lion public AddObserver route to __CFXNotificationRegisterObserver missing")
    if not post_route:
        issues.append("Lion public PostNotificationWithOptions route to __CFXNotificationPost missing")
    if not check_present:
        issues.append("Lion ___checkDelivImmed symbol missing")


def validate_targets(evidence, targets, label, issues):
    if not evidence.get("slice", False):
        issues.append("%s slice missing" % label)
        return
    for target in targets:
        if not evidence.get("target:" + target, False):
            issues.append("%s target missing: %s" % (label, target))


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="distnotify-bridge-preflight.")
    issues = []
    library_evidence = {}

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        with open(report, "w") as fp:
            line(fp, "== Distributed notifications bridge preflight audit ==")
            line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            line(fp, "product_version=%s" % product)
            line(fp, "build_version=%s" % build)
            line(fp, "selected_lion_service=com.apple.distributed_notifications@Uv3")
            line(fp, "v1_result=architecture closed: no PPC-callable XPC provider on Lion")
            line(fp, "objective=prove public-API reconstruction boundary for native i386 broker")

            if product == "10.6.8":
                ppc = inspect_cf_slice(
                    fp, "ppc7400", SNOW_CLIENT_TARGETS,
                    "Snow client CoreFoundation", tempdir)
                server_i386 = inspect_cf_slice(
                    fp, "i386", SNOW_SERVER_TARGETS,
                    "Snow server CoreFoundation", tempdir)
                validate_targets(ppc, SNOW_CLIENT_TARGETS, "Snow PPC client", issues)
                validate_targets(server_i386, SNOW_SERVER_TARGETS, "Snow i386 server", issues)
                check_snow_semantics(ppc, server_i386, fp, issues)
                lion = {}
            elif product == "10.7.5":
                lion = inspect_cf_slice(
                    fp, "i386", LION_TARGETS,
                    "Lion client CoreFoundation", tempdir)
                validate_targets(lion, LION_TARGETS, "Lion i386 client", issues)
                ppc = {}
                server_i386 = {}
                check_lion_public_routes(lion, fp, issues)
            else:
                ppc = {}
                server_i386 = {}
                lion = {}
                issues.append("unsupported OS baseline: %s" % product)

            for path, label in LIBRARY_CANDIDATES:
                inspect_library(fp, path, label, tempdir, library_evidence)

            ppc_xpc = ppc_callable_xpc_surface(library_evidence)
            line(fp)
            line(fp, "== Bridge architecture discriminator ==")
            line(fp, "ppc_callable_xpc_surface=%s" %
                 ("YES" if ppc_xpc else "NO"))
            if ppc_xpc:
                line(fp, "selected_bridge_architecture=UNEXPECTED_PPC_XPC_SURFACE_REVIEW_REQUIRED")
            else:
                line(fp, "selected_bridge_architecture=native_i386_broker_using_Lion_public_CFNotificationCenter_API")
            line(fp, "raw_xpc_bridge=REJECTED")
            line(fp, "first_proof_scope=register -> current-session post -> callback -> unregister")
            line(fp, "first_proof_guardrails=reject suspend,session_reset,post_all_sessions,sux_true")
            line(fp, "next_after_pass=standalone native i386 broker proof; still no CreateNewWindow integration")

            if product == "10.7.5":
                libxpc_i386 = (
                    library_evidence.get(("libxpc.system", "i386", "present"), False) and
                    library_evidence.get(("libxpc.system", "i386", "xpc_create"), False) and
                    library_evidence.get(("libxpc.system", "i386", "xpc_send"), False)
                )
                if not libxpc_i386:
                    issues.append("Lion native i386 libxpc create/send surface missing")
                if ppc_xpc:
                    issues.append("unexpected PPC-callable XPC surface appeared on Lion")

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
            line(fp, "No XPC connection or message was created or sent.")
            line(fp, "No bootstrap lookup or Mach request was issued.")
            line(fp, "No distributed notification was registered, posted, removed, suspended, or delivered.")
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
