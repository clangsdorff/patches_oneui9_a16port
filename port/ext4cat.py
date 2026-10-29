#!/usr/bin/env python3
"""Minimal read-only ext4 reader: list a directory or dump a file.

Only what an APEX payload needs: extents, linear/htree directories (leaf
blocks are scanned linearly). Prints the image offsets of a file's extents
with --map so bytes can be patched in place.
"""
import struct
import sys


class Ext4:
    def __init__(self, path):
        self.f = open(path, "rb")
        sb = self.read(1024, 1024)
        self.bs = 1024 << struct.unpack_from("<I", sb, 24)[0]
        self.ipg = struct.unpack_from("<I", sb, 40)[0]
        self.isz = struct.unpack_from("<H", sb, 88)[0]
        incompat = struct.unpack_from("<I", sb, 96)[0]
        self.dsz = struct.unpack_from("<H", sb, 254)[0] if incompat & 0x80 else 32
        self.gdt = (struct.unpack_from("<I", sb, 20)[0] + 1) * self.bs

    def read(self, off, n):
        self.f.seek(off)
        return self.f.read(n)

    def inode(self, ino):
        g, i = divmod(ino - 1, self.ipg)
        gd = self.read(self.gdt + g * self.dsz, self.dsz)
        table = struct.unpack_from("<I", gd, 8)[0]
        if self.dsz >= 64:
            table |= struct.unpack_from("<I", gd, 0x28)[0] << 32
        return self.read(table * self.bs + i * self.isz, self.isz)

    def extents(self, node):
        magic, entries, _, depth = struct.unpack_from("<HHHH", node, 0)
        if magic != 0xF30A:
            raise ValueError("not an extent tree")
        out = []
        for e in range(entries):
            o = 12 + e * 12
            if depth == 0:
                lblk, ln, hi, lo = struct.unpack_from("<IHHI", node, o)
                out.append((lblk, (hi << 32) | lo, ln & 0x7FFF))
            else:
                lo, hi = struct.unpack_from("<IH", node, o + 4)
                out += self.extents(self.read(((hi << 32) | lo) * self.bs, self.bs))
        return out

    def file(self, ino):
        ind = self.inode(ino)
        size = struct.unpack_from("<I", ind, 4)[0] | (struct.unpack_from("<I", ind, 108)[0] << 32)
        ext = sorted(self.extents(ind[40:100]))
        return size, ext

    def data(self, ino):
        size, ext = self.file(ino)
        buf = bytearray()
        for lblk, pblk, ln in ext:
            buf[lblk * self.bs:] = self.read(pblk * self.bs, ln * self.bs)
        return bytes(buf[:size])

    def listdir(self, ino):
        d = self.data(ino)
        out, o = {}, 0
        while o + 8 <= len(d):
            child, rec, nlen = struct.unpack_from("<IHB", d, o)
            if rec < 8:
                break
            if child:
                out[d[o + 8:o + 8 + nlen].decode(errors="replace")] = child
            o += rec
        return out

    def lookup(self, path):
        ino = 2
        for part in [p for p in path.split("/") if p]:
            ino = self.listdir(ino)[part]
        return ino


def main():
    if len(sys.argv) < 4 or sys.argv[1] not in ("ls", "cat", "map"):
        sys.exit("usage: ext4cat.py ls|cat|map <image> <path> [out]")
    fs = Ext4(sys.argv[2])
    ino = fs.lookup(sys.argv[3])
    if sys.argv[1] == "ls":
        for n in sorted(fs.listdir(ino)):
            print(n)
    elif sys.argv[1] == "map":
        size, ext = fs.file(ino)
        print("size", size)
        for lblk, pblk, ln in ext:
            print(f"file_off {lblk * fs.bs:#x} image_off {pblk * fs.bs:#x} len {ln * fs.bs:#x}")
    else:
        open(sys.argv[4], "wb").write(fs.data(ino))


if __name__ == "__main__":
    main()
