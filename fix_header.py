#!/usr/bin/env python3
"""Rewrite a .bit file's text header the way Vivado writes it.

xc7frames2bit names the part "xc7a35tcpg236-1"; Vivado writes "7a35tcpg236".
The Basys 3's USB-stick loader (on-board PIC24) may read this header, so we
match Vivado's style. Only header fields a (design) and b (part) change; the
configuration data (field e onwards) is copied byte for byte.

usage: fix_header.py in.bit out.bit
"""
import struct
import sys

DESIGN = b"top;UserID=0XFFFFFFFF;Version=2023.2"
PART = b"7a35tcpg236"


def main(src, dst):
    data = open(src, "rb").read()
    magic_len = struct.unpack(">H", data[0:2])[0]
    pos = 2 + magic_len
    assert struct.unpack(">H", data[pos:pos + 2])[0] == 1, "unexpected header"
    head = data[:pos + 2]
    pos += 2

    fields = {}
    while data[pos:pos + 1] != b"e":
        key = data[pos:pos + 1].decode()
        n = struct.unpack(">H", data[pos + 1:pos + 3])[0]
        fields[key] = data[pos + 3:pos + 3 + n].rstrip(b"\0")
        pos += 3 + n
    payload = data[pos:]                    # 'e' + 4-byte length + config data
    assert set(fields) == {"a", "b", "c", "d"}, f"unexpected fields {fields}"

    fields["a"], fields["b"] = DESIGN, PART
    out = bytearray(head)
    for key in "abcd":
        val = fields[key] + b"\0"
        out += key.encode() + struct.pack(">H", len(val)) + val
    out += payload
    open(dst, "wb").write(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
