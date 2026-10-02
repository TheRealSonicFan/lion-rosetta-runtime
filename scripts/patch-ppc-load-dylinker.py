#!/usr/bin/python
from __future__ import print_function

import struct
import sys

MH_MAGIC = 0xfeedface
CPU_TYPE_POWERPC = 18
MH_EXECUTE = 2
LC_LOAD_DYLINKER = 0x0e
MACH_HEADER_SIZE = 28


def fail(message):
    sys.stderr.write("error: %s\n" % message)
    sys.exit(1)


if len(sys.argv) != 3:
    fail("usage: %s <ppc-mach-o> <new-dylinker-path>" % sys.argv[0])

path = sys.argv[1]
new_path = sys.argv[2]

if "\0" in new_path:
    fail("dylinker path contains NUL")

try:
    data = open(path, "rb").read()
except IOError as exc:
    fail("cannot read %s: %s" % (path, exc))

if len(data) < MACH_HEADER_SIZE:
    fail("%s is too small to be a 32-bit Mach-O" % path)

if struct.unpack(">I", data[0:4])[0] == MH_MAGIC:
    endian = ">"
elif struct.unpack("<I", data[0:4])[0] == MH_MAGIC:
    endian = "<"
else:
    fail("%s is not a 32-bit MH_MAGIC Mach-O" % path)

header = struct.unpack(endian + "7I", data[0:MACH_HEADER_SIZE])
cputype = header[1]
filetype = header[3]
ncmds = header[4]
sizeofcmds = header[5]

if cputype != CPU_TYPE_POWERPC:
    fail("%s is not CPU_TYPE_POWERPC (cputype=%#x)" % (path, cputype))
if filetype != MH_EXECUTE:
    fail("%s is not MH_EXECUTE (filetype=%#x)" % (path, filetype))

commands_end = MACH_HEADER_SIZE + sizeofcmds
if commands_end > len(data):
    fail("load-command region extends beyond end of file")

offset = MACH_HEADER_SIZE
match = None

for index in range(ncmds):
    if offset + 8 > commands_end:
        fail("truncated load command %d" % index)

    cmd, cmdsize = struct.unpack(endian + "2I", data[offset:offset + 8])
    if cmdsize < 8 or offset + cmdsize > commands_end:
        fail("invalid load command %d size %#x" % (index, cmdsize))

    if cmd == LC_LOAD_DYLINKER:
        if match is not None:
            fail("multiple LC_LOAD_DYLINKER commands found")
        if cmdsize < 12:
            fail("LC_LOAD_DYLINKER command is too small")

        name_offset = struct.unpack(endian + "I", data[offset + 8:offset + 12])[0]
        if name_offset < 12 or name_offset >= cmdsize:
            fail("invalid LC_LOAD_DYLINKER name offset %#x" % name_offset)

        field_start = offset + name_offset
        field_end = offset + cmdsize
        field = data[field_start:field_end]
        nul = field.find("\0")
        if nul < 0:
            fail("LC_LOAD_DYLINKER path is not NUL terminated")

        old_path = field[:nul]
        capacity = field_end - field_start
        match = (field_start, field_end, old_path, capacity)

    offset += cmdsize

if match is None:
    fail("no LC_LOAD_DYLINKER command found")

field_start, field_end, old_path, capacity = match
if len(new_path) + 1 > capacity:
    fail("new dylinker path is too long: %d bytes; command permits at most %d"
         % (len(new_path), capacity - 1))

replacement = new_path + ("\0" * (capacity - len(new_path)))
patched = data[:field_start] + replacement + data[field_end:]

try:
    out = open(path, "wb")
    out.write(patched)
    out.close()
except IOError as exc:
    fail("cannot write %s: %s" % (path, exc))

print("Patched LC_LOAD_DYLINKER:")
print("  old: %s" % old_path)
print("  new: %s" % new_path)
print("  command path capacity: %d bytes including NUL" % capacity)
