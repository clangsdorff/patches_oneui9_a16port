#!/usr/bin/env python3
"""Copy files listed in from_target.txt from the target stock ROM into the tree.

Existing files are overwritten in place so their xattrs survive; new files and
directories get a SELinux label (system_lib_file for lib*/, system_file else).
Ownership is left to romkit apply-owner.
"""
import ctypes
import os
import shutil
import sys

libc = ctypes.CDLL(None)


def label(path):
    rel = path.split("/system/system/", 1)[-1]
    ctx = "u:object_r:system_lib_file:s0" if rel.startswith(("lib/", "lib64/")) and not os.path.isdir(path) \
        else "u:object_r:system_file:s0"
    v = ctx.encode() + b"\x00"
    if libc.setxattr(path.encode(), b"security.selinux", v, len(v), 0, 0x0001) != 0:
        sys.exit(f"setxattr failed: {path}")


def put(src, dst):
    if os.path.isdir(src):
        if not os.path.isdir(dst):
            os.makedirs(dst)
            os.chmod(dst, 0o755)
            label(dst)
        for n in sorted(os.listdir(src)):
            put(os.path.join(src, n), os.path.join(dst, n))
        return
    new = not os.path.exists(dst)
    with open(src, "rb") as i, open(dst, "wb") as o:
        shutil.copyfileobj(i, o)
    if new:
        os.chmod(dst, 0o644)
        label(dst)


def main(listfile, src_root, dst_root):
    for rel in open(listfile).read().split():
        src = os.path.join(src_root, rel)
        if not os.path.exists(src):
            sys.exit(f"missing in target: {rel}")
        put(src, os.path.join(dst_root, rel))
        print("added", rel)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: from_target.py <list> <target_rom_root> <tree_root>")
    main(*sys.argv[1:])
