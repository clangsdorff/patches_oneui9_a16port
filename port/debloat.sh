#!/usr/bin/env bash
set -e
TREE="${1:?usage: debloat.sh <tree_dir>}"
LIST="$(dirname "$0")/debloat.txt"
while IFS= read -r p; do
    [ -n "$p" ] || continue
    rm -rf "${TREE:?}/$p"
done < "$LIST"
