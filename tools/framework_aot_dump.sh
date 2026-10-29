#!/usr/bin/env bash
# Compile the boot image (whole BOOTCLASSPATH) and every framework jar with
# dex2oat "speed" on a rooted Android 14+ device, then pull the results into
# <output_dir> using the system layout:
#   system/framework/<isa>/boot*.{art,oat,vdex}
#   system/framework/oat/<isa>/<jar>.{odex,vdex}
#   mapping.txt  (jar -> files)
#
# Usage: ./framework_aot_dump.sh <output_dir>
set -euo pipefail

OUT=${1:?usage: $0 <output_dir>}
W=/data/local/tmp/aot_dump
mkdir -p "$OUT"

[ "$(adb shell "su -c 'id -u'" | tr -d '\r')" = 0 ] || { echo "ERROR: su failed"; exit 1; }

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

cat >"$TMP" <<'EOF'
set -u
set -f
W=/data/local/tmp/aot_dump
OUT=$W/out
ART=/apex/com.android.art

[ "$(getprop ro.build.version.sdk)" -ge 34 ] || { echo "ERROR: Android 14+ required"; exit 1; }

# Read classpath variables from zygote, fall back to our own environment.
getenv() {
	v=$(tr '\000' '\n' 2>/dev/null <"/proc/$(pidof zygote64 zygote | cut -d' ' -f1)/environ" | grep "^$1=" | cut -d= -f2-)
	[ -n "$v" ] || eval "v=\${$1:-}"
	echo "$v"
}
BCP=$(getenv BOOTCLASSPATH)
SSCP=$(getenv SYSTEMSERVERCLASSPATH)
SSSA=$(getenv STANDALONE_SYSTEMSERVER_JARS)
[ -n "$BCP" ] || { echo "ERROR: BOOTCLASSPATH not found"; exit 1; }

DEX2OAT=$ART/bin/dex2oat64
[ -x "$DEX2OAT" ] || DEX2OAT=$ART/bin/dex2oat32

abi2isa() {
	case $1 in
	arm64-v8a) echo arm64 ;;
	armeabi-v7a) echo arm ;;
	x86_64) echo x86_64 ;;
	x86) echo x86 ;;
	esac
}
ISA64=$(abi2isa "$(getprop ro.product.cpu.abilist64 | cut -d, -f1)")
ISA32=$(abi2isa "$(getprop ro.product.cpu.abilist32 | cut -d, -f1)")
case $(getprop ro.zygote) in
zygote64) ISAS=$ISA64 ;;
zygote32) ISAS=$ISA32 ;;
*) ISAS="$ISA64 $ISA32" ;;
esac
SS_ISA=${ISAS%% *}

rm -rf "$W/out" "$W/empty"
mkdir -p "$OUT" "$W/empty"
: >"$W/mapping.txt"
FAILED=

common() {
	a="--compiler-filter=speed -j$(nproc) --instruction-set=$1"
	v=$(getprop "dalvik.vm.isa.$1.variant")
	[ -n "$v" ] && a="$a --instruction-set-variant=$v"
	v=$(getprop "dalvik.vm.isa.$1.features")
	[ -n "$v" ] && a="$a --instruction-set-features=$v"
	echo "$a --android-root=$W/empty --force-determinism --avoid-storing-invocation" \
		"--no-abort-on-hard-verifier-error --image-format=lz4hc --generate-mini-debug-info --strip" \
		"--runtime-arg -Xbootclasspath:$BCP"
}

# 1. Boot image: one primary image over the whole BOOTCLASSPATH, one file set per jar.
# Image classes come from the stock profile; without it dex2oat initializes
# every class and aborts in a Samsung static initializer.
for isa in $ISAS; do
	d=$OUT/system/framework/$isa
	mkdir -p "$d"
	args="$(common "$isa") --profile-file=/system/etc/boot-image.prof --preloaded-classes=/system/etc/preloaded-classes --dirty-image-objects=/system/etc/dirty-image-objects --base=0x70000000 --image=$d/boot.art --oat-file=$d/boot.oat --oat-location=/system/framework/$isa/boot.oat"
	name=
	for j in $(echo "$BCP" | tr ':' ' '); do
		args="$args --dex-file=$j --dex-location=$j"
		# dex2oat names the first jar boot.*, every other jar boot-<jar>.*
		b=${j##*/}
		if [ -z "$name" ]; then name=boot; else name=boot-${b%.jar}; fi
		echo "$j -> system/framework/$isa/$name.art $name.oat $name.vdex" >>"$W/mapping.txt"
	done
	echo "[$isa] boot image ($(echo "$BCP" | tr ':' ' ' | wc -w) jars)"
	$DEX2OAT $args >"$W/boot-$isa.log" 2>&1 || { tail -n 20 "$W/boot-$isa.log"; echo "ERROR: boot image failed"; exit 1; }
done

# 2. Framework jars -> oat/<isa>/<jar>.odex
odex() {
	case $2 in
	/apex/*) loc=/system/framework/oat/$1/$(echo "${2#/}" | tr '/' '@')@classes.odex ;;
	*)
		b=${2##*/}
		loc=${2%/*}/oat/$1/${b%.jar}.odex
		;;
	esac
	mkdir -p "$OUT${loc%/*}"
	echo "[$1] $2"
	if $DEX2OAT $(common "$1") --boot-image="$OUT/system/framework/boot.art" \
		--dex-file="$2" --dex-location="$2" --class-loader-context="$3" \
		--oat-file="$OUT$loc" --oat-location="$loc" --output-vdex="$OUT${loc%.odex}.vdex" >"$W/odex.log" 2>&1; then
		echo "$2 -> ${loc#/} ${loc##*/}" | sed 's/\.odex$/.vdex/' >>"$W/mapping.txt"
	else
		tail -n 5 "$W/odex.log"
		FAILED="$FAILED $2"
	fi
}

# system_server jars (class loader context as odrefresh builds it)
CTX=
for j in $(echo "$SSCP" | tr ':' ' '); do
	odex "$SS_ISA" "$j" "PCL[$CTX]"
	CTX=${CTX:+$CTX:}$j
done
for j in $(echo "$SSSA" | tr ':' ' '); do
	odex "$SS_ISA" "$j" "PCL[];PCL[$SSCP]"
done

# Remaining jars in /system/framework that contain dex code
for n in $(ls /system/framework | grep '\.jar$'); do
	j=/system/framework/$n
	case ":$BCP:$SSCP:$SSSA:" in *":$j:"*) continue ;; esac
	unzip -l "$j" 2>/dev/null | grep -q 'classes[0-9]*\.dex' || continue
	for isa in $ISAS; do odex "$isa" "$j" "PCL[]"; done
done

[ -z "$FAILED" ] || echo "FAILED:$FAILED"
echo DONE
EOF

adb push "$TMP" "$W.sh" >/dev/null 2>&1 || { echo "ERROR: adb push failed"; exit 1; }
adb shell -T "su -c 'sh $W.sh'" | tee "$OUT/log.txt" || true
grep -q '^DONE$' "$OUT/log.txt" || { echo "ERROR: compile failed, see $OUT/log.txt"; exit 1; }

adb exec-out "su -c 'tar -cf - -C $W/out .'" | tar -xf - -C "$OUT"
adb exec-out "su -c 'cat $W/mapping.txt'" >"$OUT/mapping.txt"
adb shell "su -c 'rm -rf $W $W.sh'"

echo "Done: $OUT/system  (mapping: $OUT/mapping.txt)"
