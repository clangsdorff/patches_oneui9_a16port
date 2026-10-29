#!/usr/bin/env python3
"""Put rebuilt targets back into the extracted trees.

Each rebuilt file replaces the original in place (contents only, so the
SELinux xattr and the ownership map entry stay valid). The stale oat/ dir and
.prof/.bprof next to it are removed, as UN1CA does.
"""
import os
import shutil
import sys

PARTS = ("system/system", "system/system/system_ext", "product")


def find_original(tree, name):
    hits = []
    for part in PARTS:
        root = os.path.join(tree, part)
        for sub in ("framework", "app", "priv-app", "apex"):
            base = os.path.join(root, sub)
            if not os.path.isdir(base):
                continue
            for d, _, files in os.walk(base):
                if name in files:
                    hits.append(os.path.join(d, name))
    return hits


def main(tree, *dirs):
    for src_dir in dirs:
        for name in sorted(os.listdir(src_dir)):
            hits = find_original(tree, name)
            if len(hits) != 1:
                sys.exit(f"{name}: expected one original in the tree, found {hits}")
            dst = hits[0]
            with open(os.path.join(src_dir, name), "rb") as i, open(dst, "wb") as o:
                shutil.copyfileobj(i, o)
            here = os.path.dirname(dst)
            if os.path.isdir(os.path.join(here, "oat")):
                shutil.rmtree(os.path.join(here, "oat"))
            for ext in (".prof", ".bprof"):
                if os.path.exists(dst + ext):
                    os.remove(dst + ext)
            print("installed", os.path.relpath(dst, tree))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit("usage: install_apks.py <tree_dir> <dir with rebuilt files>...")
    main(*sys.argv[1:])
