#!/usr/bin/env python3
"""Rewrite smali_classesN paths in a patch to where each class lives in a decode.

Classes move between dex files across firmware versions; the hunks usually
still apply once the path is right. Paths that cannot be found are reported
and left as they are.
"""
import os
import re
import sys

SMALI = re.compile(r"^(smali(?:_classes\d+)?)/(.+\.smali)$")


def find(workdir, rel):
    m = SMALI.match(rel)
    if not m or os.path.exists(os.path.join(workdir, rel)):
        return rel
    for d in sorted(os.listdir(workdir)):
        if re.fullmatch(r"smali(_classes\d+)?", d) and os.path.exists(os.path.join(workdir, d, m.group(2))):
            return f"{d}/{m.group(2)}"
    return None


def main(patch, workdir, out):
    moved, missing = {}, set()
    text = open(patch, encoding="utf-8", errors="surrogateescape").read()

    def fix(rel):
        if rel in moved:
            return moved[rel]
        new = find(workdir, rel)
        if new is None:
            missing.add(rel)
            new = rel
        moved[rel] = new
        return new

    lines = []
    for line in text.splitlines(keepends=True):
        m = re.match(r"^diff --git a/(\S+) b/(\S+)(\s*)$", line)
        if m:
            line = f"diff --git a/{fix(m.group(1))} b/{fix(m.group(2))}{m.group(3)}"
        else:
            m = re.match(r"^(---|\+\+\+) ([ab])/(\S+)(\s*)$", line)
            if m:
                line = f"{m.group(1)} {m.group(2)}/{fix(m.group(3))}{m.group(4)}"
        lines.append(line)
    with open(out, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.writelines(lines)
    for old, new in sorted(moved.items()):
        if old != new and old not in missing:
            print(f"moved   {old} -> {new}")
    for p in sorted(missing):
        print(f"missing {p}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: relocate_patch.py <patch> <decoded_dir> <out_patch>")
    main(*sys.argv[1:])
