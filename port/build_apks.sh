#!/usr/bin/env bash
# Rebuild every patched target from unpacked/<base>_work into out/apks/.
# JARs come out zipaligned and ready; APKs come out zipaligned but unsigned
# (out/apks/unsigned), sign them with port/sign.sh.
set -e

cd "$(dirname "$0")/.."

SIGN_CERT="${SIGN_CERT:?set SIGN_CERT to your platform x509 pem}"
BT="$(ls -d "$HOME"/Library/Android/sdk/build-tools/* | sort -V | tail -1)"
APKTOOL="java -jar apktool.jar"
TARGETS="${*:-$(ls patches | sed 's/_out\.patch$//')}"

mkdir -p out/apks/unsigned out/apks/jar work/build

for b in $TARGETS; do
    src="unpacked/${b}_work"
    if [ -f "apks/$b.jar" ]; then ext=jar; else ext=apk; fi
    tmp="work/build/$b"
    echo "[*] $b.$ext"
    rm -rf "$tmp"
    rsync -a --exclude .git "$src/" "$tmp/"

    if grep -rlq "PUT SIGNATURE HERE" "$tmp"; then
        [ -f "$SIGN_CERT" ] || { echo "[!] $SIGN_CERT not found"; exit 1; }
        sig="$(sed '/CERTIFICATE/d' "$SIGN_CERT" | tr -d '\n' | base64 -d | xxd -p -c 0)"
        grep -rl --include="*.smali" "PUT SIGNATURE HERE" "$tmp" | while IFS= read -r f; do
            sed "s|PUT SIGNATURE HERE|$sig|g" "$f" > "$f.sigtmp" && mv "$f.sigtmp" "$f"
        done
        echo "    platform signature from $SIGN_CERT"
    fi

    if [ -d "$tmp/original/META-INF" ]; then
        mkdir -p "$tmp/build/apk"
        cp -a "$tmp/original/META-INF" "$tmp/build/apk/META-INF"
    fi

    $APKTOOL b -p apktool_frameworks -o "$tmp.$ext" "$tmp" > "work/build/$b.log" 2>&1 \
        || { echo "[!] build failed, see work/build/$b.log"; exit 1; }

    if [ "$ext" = jar ]; then
        "$BT/zipalign" -f -p 4 "$tmp.$ext" "out/apks/jar/$b.jar"
    else
        "$BT/zipalign" -f -p 4 "$tmp.$ext" "out/apks/unsigned/$b.apk"
    fi
    rm -rf "$tmp" "$tmp.$ext"
done
