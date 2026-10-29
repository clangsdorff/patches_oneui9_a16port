#!/usr/bin/env python3
"""Summarise a smali patch per method: post-image body when a hunk holds the whole
method, otherwise the changed lines with a little context. Used to port ui8
patches to recipes by hand.
"""
import re
import sys


def hunks(patch):
    out = []
    cur_file, cur = None, None
    for line in open(patch, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("diff --git"):
            cur_file = line.split(" b/", 1)[1]
            continue
        if line.startswith(("---", "+++", "index ", "new file", "deleted file", "similarity", "rename")):
            continue
        if line.startswith("@@"):
            cur = []
            out.append((cur_file, cur))
            continue
        if cur is not None:
            cur.append(line)
    return out


def main(patch):
    for f, h in hunks(patch):
        post = [l[1:] for l in h if l[:1] in (" ", "+")]
        cls = re.sub(r"^smali(_classes\d+)?/", "", f).removesuffix(".smali")
        starts = [i for i, l in enumerate(post) if l.startswith(".method")]
        changed = any(l[:1] in "+-" for l in h)
        if not changed:
            continue
        print(f"=== {cls}")
        for i in starts:
            try:
                e = next(j for j in range(i, len(post)) if post[j].startswith(".end method"))
            except StopIteration:
                e = None
            seg_h = h  # whole hunk view for partial
            if e is not None:
                print(f"  FULL {post[i]}")
                for l in post[i + 1:e]:
                    if l.strip():
                        print(f"      {l.strip()}")
        if not starts or any(l.startswith(".end method") for l in post[:starts[0]] if starts):
            print("  PARTIAL hunk:")
            for l in h:
                if l[:1] in "+-" and l[1:].strip():
                    print(f"    {l}")


if __name__ == "__main__":
    main(sys.argv[1])
