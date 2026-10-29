#!/usr/bin/env bash
# Copy the dex2oat output pulled by tools/*_aot_dump.sh into the trees, as
# root:root 644/755 with the system_file label. Run as root.
set -e

cd "$(dirname "$0")/.."

copy() {
    src=$1 dst=$2
    [ -d "$src" ] || return 0
    (cd "$src" && find . -type d) | while IFS= read -r d; do
        [ -d "$dst/$d" ] || { mkdir "$dst/$d"; echo "$dst/${d#./}" >> work/aot_new_dirs.txt; }
    done
    (cd "$src" && find . -type f) | while IFS= read -r f; do
        cp "$src/$f" "$dst/$f"
        echo "$dst/${f#./}" >> work/aot_new_files.txt
    done
}

: > work/aot_new_dirs.txt
: > work/aot_new_files.txt
copy work/aot/system/framework work/tree/system/system/framework
copy work/aot_apps/system work/tree/system/system
copy work/aot_apps/product work/tree/product

cat work/aot_new_dirs.txt | tr '\n' '\0' | xargs -0 -r chown 0:0
cat work/aot_new_dirs.txt | tr '\n' '\0' | xargs -0 -r chmod 755
cat work/aot_new_files.txt | tr '\n' '\0' | xargs -0 -r chown 0:0
cat work/aot_new_files.txt | tr '\n' '\0' | xargs -0 -r chmod 644
cat work/aot_new_dirs.txt work/aot_new_files.txt | tr '\n' '\0' \
    | xargs -0 -r python3 port/label.py u:object_r:system_file:s0
echo "$(wc -l < work/aot_new_dirs.txt) dirs, $(wc -l < work/aot_new_files.txt) files"
