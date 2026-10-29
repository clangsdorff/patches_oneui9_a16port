#!/usr/bin/env python3
"""Set security.selinux on files (macOS has no os.setxattr)."""
import ctypes
import sys

libc = ctypes.CDLL(None)
label = sys.argv[1].encode() + b"\x00"
for p in sys.argv[2:]:
    if libc.setxattr(p.encode(), b"security.selinux", label, len(label), 0, 0x0001) != 0:
        sys.exit(f"setxattr failed: {p}")
