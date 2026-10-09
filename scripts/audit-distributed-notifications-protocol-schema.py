#!/usr/bin/python
from __future__ import print_function

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

DEFAULT_REPORT = "./distributed-notifications-protocol-schema.txt"
ANALYZER_VERSION = "1"

COREFOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
DISTNOTED = "/usr/sbin/distnoted"

SNOW_SERVICE = "com.apple.distributed_notifications.2"
LION_SERVICE = "com.apple.distributed_notifications@Uv3"

SNOW_TARGETS = [
    "___CFXNotificationSendToServer",
    "___CFXNotificationHandleMessage",
    "___CFXNotificationReceiveFromServer",
    "__CFXNotificationPostNotification",
    "__CFXNotificationPost",
    "__CFXNotificationUnregister",
    "__CFXNotificationRegister",
    "___CFXNotificationSendToClient",
    "___CFXNotificationReceiveFromClient",
]

LION_TARGETS = [
    "__CFXNotificationRegisterObserver",
    "__CFXNotificationPost",
    "___CFXNotificationCenterCreate",
    "___CFXNotificationCenterSetupConnection",
    "_____CFXNotificationCenterSetupConnection_block_invoke_1",
    "__CFXNotificationRemoveObservers",
    "___CFXNotificationPostToken",
    "_____CFXNotificationPostToken_block_invoke_1",
    "____CFXNotificationRegisterObserver_block_invoke_1",
]

LIKELY_PROTOCOL_RE = re.compile(
    r"(notification|register|unregister|remove|post|object|name|token|"
    r"session|pid|user|deliver|suspend|connection|message|request|reply|"
    r"version|type|flags|distributed)",
    re.I,
)

XPC_TRANSPORT_RE = re.compile(
    r"(_xpc_dictionary_|_xpc_array_|_xpc_data_|"
    r"_xpc_connection_send_message|_xpc_connection_get_remote_connection)",
    re.I,
)


def run(cmd):
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.communicate()[0]
    except OSError as exc:
        return 127, "exec_failed: %s" % exc
    if not isinstance(out, str):
        out = out.decode("utf-8", "replace")
    return p.returncode, out


def write_line(fp, text=""):
    if not isinstance(text, str):
        try:
            text = text.encode("utf-8")
        except Exception:
            text = str(text)
    fp.write(text)
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


def parse_nm_text_symbol_name(line):
    marker = "(__TEXT,__text)"
    if marker not in line:
        return None
    tail = line.split(marker, 1)[1].strip()
    prefixes = [
        "non-external (was a private external) ",
        "non-external ",
        "external ",
    ]
    for prefix in prefixes:
        if tail.startswith(prefix):
            return tail[len(prefix):].strip()
    return tail if tail else None


def parse_symbols(text):
    ordered = []
    by_name = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        if "(__TEXT,__text)" not in line:
            continue
        name = parse_nm_text_symbol_name(line)
        if not name:
            continue
        ordered.append((addr, name))
        by_name.setdefault(name, []).append(addr)
    ordered.sort()
    return ordered, by_name


def parse_instructions(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        rows.append((addr, line))
    return rows


def next_symbol_address(ordered, start):
    for addr, name in ordered:
        if addr > start:
            return addr
    return None


def symbol_rows(rows, ordered, start, max_bytes=0x8000):
    end = start + max_bytes
    nxt = next_symbol_address(ordered, start)
    if nxt is not None:
        end = min(end, nxt)
    return [(addr, line) for addr, line in rows if addr >= start and addr < end]


def parse_sections(path):
    rc, out = run(["/usr/bin/otool", "-l", path])
    sections = {}
    if rc != 0:
        return sections

    current = None
    for raw in out.splitlines():
        line = raw.strip()
        if line.startswith("Load command "):
            if current and current.get("sectname") and current.get("segname"):
                sections[(current["segname"], current["sectname"])] = current
            current = None
            continue
        if line == "Section":
            if current and current.get("sectname") and current.get("segname"):
                sections[(current["segname"], current["sectname"])] = current
            current = {}
            continue
        if current is None:
            continue
        parts = line.split(None, 1)
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
    if "offset" not in info or "size" not in info or "addr" not in info:
        return None, None
    try:
        fp = open(path, "rb")
        try:
            fp.seek(info["offset"])
            blob = fp.read(info["size"])
        finally:
            fp.close()
    except IOError:
        return None, None
    return info, blob


def decode_bytes(raw):
    if isinstance(raw, str):
        return raw
    return raw.decode("utf-8", "replace")


def cstring_map(path, sections):
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


def cfstring_map(path, sections, arch, cstrings):
    info, blob = read_section(path, sections, "__DATA", "__cfstring")
    result = {}
    if info is None or blob is None:
        return result

    endian = ">" if arch.startswith("ppc") else "<"
    entry_size = 16
    for off in range(0, len(blob) - entry_size + 1, entry_size):
        chunk = blob[off:off + entry_size]
        try:
            words = struct.unpack(endian + "IIII", chunk)
        except Exception:
            continue
        value = None
        for word in words:
            if word in cstrings:
                value = cstrings[word]
                break
        if value is not None:
            result[info["addr"] + off] = value
    return result


def signed16(value):
    value &= 0xffff
    if value & 0x8000:
        value -= 0x10000
    return value


def signed32(value):
    value &= 0xffffffff
    if value & 0x80000000:
        value -= 0x100000000
    return value


def constant_at(addr, cstrings, cfstrings):
    if addr in cstrings:
        return "cstring", cstrings[addr]
    if addr in cfstrings:
        return "cfstring", cfstrings[addr]
    return None


def resolve_i386(rows, cstrings, cfstrings):
    refs = []
    expr = {}
    pending_call_target = None

    for addr, line in rows:
        stripped = line.strip()

        m = re.search(r"\bcalll\s+0x([0-9a-fA-F]+)", stripped)
        if m:
            pending_call_target = int(m.group(1), 16)

        m = re.search(r"\bpopl\s+%(e[a-z]{2})\b", stripped)
        if m and pending_call_target is not None:
            expr[m.group(1)] = pending_call_target
            pending_call_target = None

        m = re.search(
            r"\bleal\s+0x([0-9a-fA-F]+)\(%(e[a-z]{2})\),%(e[a-z]{2})",
            stripped,
        )
        if m:
            disp = signed32(int(m.group(1), 16))
            src = m.group(2)
            dst = m.group(3)
            if src in expr:
                value = (expr[src] + disp) & 0xffffffff
                expr[dst] = value
                hit = constant_at(value, cstrings, cfstrings)
                if hit:
                    refs.append((addr, line, value, hit[0], hit[1]))
            else:
                expr.pop(dst, None)

        m = re.search(r"\bmovl\s+\$0x([0-9a-fA-F]+),%(e[a-z]{2})", stripped)
        if m:
            value = int(m.group(1), 16) & 0xffffffff
            dst = m.group(2)
            expr[dst] = value
            hit = constant_at(value, cstrings, cfstrings)
            if hit:
                refs.append((addr, line, value, hit[0], hit[1]))

        if re.search(r"\bret\b", stripped):
            expr = {}
            pending_call_target = None

    return refs


def resolve_ppc(rows, cstrings, cfstrings):
    refs = []
    expr = {}
    lr_value = None

    for addr, line in rows:
        stripped = line.strip()

        m = re.search(r"\bbcl\s+[^,]+,[^,]+,0x([0-9a-fA-F]+)", stripped)
        if m:
            lr_value = int(m.group(1), 16)

        m = re.search(r"\bmfspr\s+(r\d+),lr", stripped)
        if m and lr_value is not None:
            expr[m.group(1)] = lr_value

        m = re.search(r"\baddis\s+(r\d+),(r\d+),0x([0-9a-fA-F]+)", stripped)
        if m:
            dst, src = m.group(1), m.group(2)
            if src in expr:
                expr[dst] = (expr[src] + (signed16(int(m.group(3), 16)) << 16)) & 0xffffffff
            else:
                expr.pop(dst, None)

        m = re.search(r"\baddi\s+(r\d+),(r\d+),0x([0-9a-fA-F]+)", stripped)
        if m:
            dst, src = m.group(1), m.group(2)
            if src in expr:
                value = (expr[src] + signed16(int(m.group(3), 16))) & 0xffffffff
                expr[dst] = value
                hit = constant_at(value, cstrings, cfstrings)
                if hit:
                    refs.append((addr, line, value, hit[0], hit[1]))
            else:
                expr.pop(dst, None)

        m = re.search(r"\bor\s+(r\d+),(r\d+),\2\b", stripped)
        if m:
            dst, src = m.group(1), m.group(2)
            if src in expr:
                expr[dst] = expr[src]

        if re.search(r"\bblr\b", stripped):
            expr = {}
            lr_value = None

    return refs


def resolve_constants(rows, arch, cstrings, cfstrings):
    if arch.startswith("ppc"):
        return resolve_ppc(rows, cstrings, cfstrings)
    return resolve_i386(rows, cstrings, cfstrings)


def emit_constant_inventory(fp, cstrings, cfstrings, all_short=False):
    write_line(fp)
    write_line(fp, "-- addressed protocol constants --")
    rows = []
    for addr, value in cstrings.items():
        if all_short:
            if len(value) <= 256:
                rows.append((addr, "cstring", value))
        elif LIKELY_PROTOCOL_RE.search(value):
            rows.append((addr, "cstring", value))
    for addr, value in cfstrings.items():
        if all_short:
            if len(value) <= 256:
                rows.append((addr, "cfstring", value))
        elif LIKELY_PROTOCOL_RE.search(value):
            rows.append((addr, "cfstring", value))

    rows.sort()
    write_line(fp, "constant_count=%d" % len(rows))
    for addr, kind, value in rows[:3000]:
        write_line(fp, "0x%x %s %s" % (addr, kind, value))
    if len(rows) > 3000:
        write_line(fp, "additional_constants_omitted=%d" % (len(rows) - 3000))


def emit_target(fp, name, addrs, rows, ordered, arch, cstrings, cfstrings):
    write_line(fp)
    write_line(fp, "-- exact target: %s count=%d --" % (name, len(addrs)))
    for start in sorted(addrs):
        window = symbol_rows(rows, ordered, start)
        write_line(fp, "-- symbol window: %s --" % name)
        write_line(fp, "symbol_address=0x%x" % start)
        for addr, line in window:
            write_line(fp, line)
        write_line(fp, "instruction_lines=%d" % len(window))

        refs = resolve_constants(window, arch, cstrings, cfstrings)
        write_line(fp, "-- resolved constant references: %s --" % name)
        write_line(fp, "resolved_constant_reference_count=%d" % len(refs))
        for addr, line, value_addr, kind, value in refs[:500]:
            write_line(fp, "instruction=0x%x constant_address=0x%x kind=%s value=%s" %
                       (addr, value_addr, kind, value))
            write_line(fp, line)
        if len(refs) > 500:
            write_line(fp, "additional_resolved_constant_references_omitted=%d" %
                       (len(refs) - 500))


def emit_xpc_contexts(fp, dis_lines, annotations):
    hits = [i for i, line in enumerate(dis_lines) if XPC_TRANSPORT_RE.search(line)]
    write_line(fp)
    write_line(fp, "-- XPC protocol callsite contexts --")
    write_line(fp, "xpc_context_hit_count=%d" % len(hits))

    emitted = 0
    last_end = -1
    for idx in hits:
        if emitted >= 180:
            break
        lo = max(0, idx - 18)
        hi = min(len(dis_lines), idx + 19)
        if lo <= last_end:
            lo = last_end + 1
        if lo >= hi:
            continue
        write_line(fp, "context_hit_line=%d" % (idx + 1))
        for j in range(lo, hi):
            write_line(fp, dis_lines[j])
            for item in annotations.get(j, []):
                value_addr, kind, value = item
                write_line(fp, "resolved_constant line=%d address=0x%x kind=%s value=%s" %
                           (j + 1, value_addr, kind, value))
        last_end = hi - 1
        emitted += 1

    if len(hits) > emitted:
        write_line(fp, "additional_xpc_context_hits_omitted=%d" % (len(hits) - emitted))


def annotate_full_i386(dis_lines, cstrings, cfstrings):
    rows = parse_instructions("\n".join(dis_lines))
    resolved = resolve_i386(rows, cstrings, cfstrings)
    by_addr = {}
    for addr, line, value_addr, kind, value in resolved:
        by_addr.setdefault(addr, []).append((value_addr, kind, value))

    annotations = {}
    for i, line in enumerate(dis_lines):
        parts = line.split(None, 1)
        if not parts:
            continue
        addr = parse_hex_token(parts[0])
        if addr is None:
            continue
        if addr in by_addr:
            annotations[i] = by_addr[addr]
    return annotations


def analyze_corefoundation(fp, path, arch, tempdir, targets, evidence):
    thin = os.path.join(tempdir, "CoreFoundation.%s" % arch)
    ok = thin_arch(path, arch, thin)
    write_line(fp)
    write_line(fp, "== CoreFoundation slice: %s ==" % arch)
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    evidence["cf_slice"] = ok
    if not ok:
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))

    sections = parse_sections(thin)
    cstrings = cstring_map(thin, sections)
    cfstrings = cfstring_map(thin, sections, arch, cstrings)
    write_line(fp, "cstring_entry_count=%d" % len(cstrings))
    write_line(fp, "cfstring_entry_count=%d" % len(cfstrings))
    evidence["cstring_map"] = bool(cstrings)
    evidence["cfstring_map"] = bool(cfstrings)
    evidence["service_string"] = (
        SNOW_SERVICE in cstrings.values() or
        SNOW_SERVICE in cfstrings.values() or
        LION_SERVICE in cstrings.values() or
        LION_SERVICE in cfstrings.values()
    )

    emit_constant_inventory(fp, cstrings, cfstrings, all_short=False)

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    write_line(fp)
    write_line(fp, "-- target symbol inventory --")
    if rc != 0:
        write_line(fp, "nm_failed")
        return
    ordered, by_name = parse_symbols(nm_out)
    for target in targets:
        write_line(fp, "%s count=%d" % (target, len(by_name.get(target, []))))
        evidence["target:" + target] = bool(by_name.get(target))

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        return
    rows = parse_instructions(dis_out)

    for target in targets:
        emit_target(fp, target, sorted(by_name.get(target, [])),
                    rows, ordered, arch, cstrings, cfstrings)


def analyze_lion_distnoted(fp, path, tempdir, evidence):
    arch = "i386"
    thin = os.path.join(tempdir, "distnoted.i386")
    ok = thin_arch(path, arch, thin)
    write_line(fp)
    write_line(fp, "== Lion distnoted i386 schema slice ==")
    write_line(fp, "thin=%s" % ("YES" if ok else "NO"))
    evidence["distnoted_slice"] = ok
    if not ok:
        return

    write_line(fp, "slice_sha256=%s" % sha256(thin))
    sections = parse_sections(thin)
    cstrings = cstring_map(thin, sections)
    cfstrings = cfstring_map(thin, sections, arch, cstrings)
    write_line(fp, "cstring_entry_count=%d" % len(cstrings))
    write_line(fp, "cfstring_entry_count=%d" % len(cfstrings))
    emit_constant_inventory(fp, cstrings, cfstrings, all_short=True)

    rc, nm_out = run(["/usr/bin/nm", "-nm", thin])
    write_line(fp)
    write_line(fp, "-- focused imports --")
    imports = []
    if rc == 0:
        imports = [line for line in nm_out.splitlines()
                   if "_xpc_" in line or "_mach_msg" in line or
                   "bootstrap_look_up" in line or "_mig_" in line]
        for line in imports:
            write_line(fp, line)

    joined = "\n".join(imports)
    evidence["distnoted_xpc_send"] = "_xpc_connection_send_message" in joined
    evidence["distnoted_xpc_dict"] = "_xpc_dictionary_" in joined
    evidence["distnoted_mach_msg"] = "_mach_msg" in joined
    evidence["distnoted_bootstrap"] = "bootstrap_look_up" in joined
    evidence["distnoted_service"] = LION_SERVICE in cstrings.values()

    rc, objc_out = run(["/usr/bin/otool", "-ov", thin])
    write_line(fp)
    write_line(fp, "-- Objective-C metadata --")
    if rc == 0:
        objc_lines = objc_out.splitlines()
        for line in objc_lines[:5000]:
            write_line(fp, line)
        if len(objc_lines) > 5000:
            write_line(fp, "additional_objc_metadata_lines_omitted=%d" %
                       (len(objc_lines) - 5000))
    else:
        write_line(fp, "otool_objc_metadata_failed")

    rc, dis_out = run(["/usr/bin/otool", "-tvV", thin])
    if rc != 0:
        write_line(fp, "disassembly_failed")
        return

    dis_lines = dis_out.splitlines()
    annotations = annotate_full_i386(dis_lines, cstrings, cfstrings)
    emit_xpc_contexts(fp, dis_lines, annotations)


def validate(product, evidence, targets, issues):
    if not evidence.get("cf_slice", False):
        issues.append("required CoreFoundation slice missing")
    if not evidence.get("cstring_map", False):
        issues.append("CoreFoundation __cstring map missing")
    if not evidence.get("cfstring_map", False):
        issues.append("CoreFoundation __cfstring map missing")
    if not evidence.get("service_string", False):
        issues.append("expected distributed-notifications service string missing")

    for target in targets:
        if not evidence.get("target:" + target, False):
            issues.append("required CoreFoundation target missing: %s" % target)

    if product == "10.7.5":
        if not evidence.get("distnoted_slice", False):
            issues.append("Lion distnoted i386 slice missing")
        if not evidence.get("distnoted_service", False):
            issues.append("Lion @Uv3 service string missing from distnoted")
        if not evidence.get("distnoted_xpc_send", False):
            issues.append("Lion distnoted XPC send import missing")
        if not evidence.get("distnoted_xpc_dict", False):
            issues.append("Lion distnoted XPC dictionary imports missing")


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPORT
    tempdir = tempfile.mkdtemp(prefix="distnotify-schema.")
    evidence = {}
    issues = []

    try:
        _, product_out = run(["/usr/bin/sw_vers", "-productVersion"])
        _, build_out = run(["/usr/bin/sw_vers", "-buildVersion"])
        product = product_out.strip()
        build = build_out.strip()

        if product == "10.6.8":
            arch = "ppc7400"
            targets = SNOW_TARGETS
        elif product == "10.7.5":
            arch = "i386"
            targets = LION_TARGETS
        else:
            arch = "i386"
            targets = []
            issues.append("unsupported OS baseline: %s" % product)

        with open(report, "w") as fp:
            write_line(fp, "== Distributed notifications protocol schema audit ==")
            write_line(fp, "analyzer_version=%s" % ANALYZER_VERSION)
            write_line(fp, "product_version=%s" % product)
            write_line(fp, "build_version=%s" % build)
            write_line(fp, "selected_lion_service=%s" % LION_SERVICE)
            write_line(fp, "protocol_boundary=name-only translation rejected by prior differential")

            if os.path.isfile(COREFOUNDATION):
                write_line(fp, "corefoundation_sha256=%s" % sha256(COREFOUNDATION))
                analyze_corefoundation(fp, COREFOUNDATION, arch, tempdir,
                                       targets, evidence)
            else:
                issues.append("CoreFoundation binary missing")

            if product == "10.7.5":
                if os.path.isfile(DISTNOTED):
                    write_line(fp)
                    write_line(fp, "distnoted_sha256=%s" % sha256(DISTNOTED))
                    analyze_lion_distnoted(fp, DISTNOTED, tempdir, evidence)
                else:
                    issues.append("Lion distnoted binary missing")

            write_line(fp)
            write_line(fp, "== Audit validation ==")
            validate(product, evidence, targets, issues)

            if product == "10.7.5":
                write_line(fp, "lion_distnoted_imports_mach_msg=%s" %
                           ("YES" if evidence.get("distnoted_mach_msg", False) else "NO"))
                write_line(fp, "lion_distnoted_imports_bootstrap_lookup=%s" %
                           ("YES" if evidence.get("distnoted_bootstrap", False) else "NO"))

            if issues:
                for issue in issues:
                    write_line(fp, "validation_issue=%s" % issue)
                write_line(fp, "RESULT: FAIL")
            else:
                write_line(fp, "RESULT: PASS")

            write_line(fp)
            write_line(fp, "== Audit integrity ==")
            write_line(fp, "No PowerPC application was launched by this audit.")
            write_line(fp, "No notification-center API was called dynamically.")
            write_line(fp, "No bootstrap lookup, Mach request, MIG request, or XPC request was issued.")
            write_line(fp, "No distributed notification was registered, posted, removed, or delivered intentionally.")
            write_line(fp, "No launchd or distnoted process was started, stopped, restarted, signaled, or modified.")
            write_line(fp, "No framework, executable, launchd plist, Rosetta component, cache, or kernel was modified.")
            write_line(fp, "Temporary architecture slices were created only under the system temporary directory and removed on exit.")

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
