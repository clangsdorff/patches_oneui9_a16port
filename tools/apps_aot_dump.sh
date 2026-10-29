#!/usr/bin/env bash
# Compile every preinstalled APK with dex2oat "speed" on a rooted device
# against the boot image produced by framework_aot_dump.sh, then pull the
# results in the system layout (<apk dir>/oat/<isa>/<name>.{odex,vdex}).
# The class loader context of each app is taken from the odex the device
# already wrote for it in /data/dalvik-cache.
#
# Usage: ./apps_aot_dump.sh <framework_aot_dir> <output_dir>
set -euo pipefail

FW=${1:?usage: $0 <framework_aot_dir> <output_dir>}
OUT=${2:?usage: $0 <framework_aot_dir> <output_dir>}
W=/data/local/tmp/aot_apps
mkdir -p "$OUT"

[ "$(adb shell "su -c 'id -u'" | tr -d '\r')" = 0 ] || { echo "ERROR: su failed"; exit 1; }

adb shell "su -c 'rm -rf $W; mkdir -p $W/boot'"
tar -cf - --exclude oat -C "$FW" system/framework | adb shell "su -c 'tar -xf - -C $W/boot'"
adb shell "pm art dump" | tr -d '\r' >"$OUT/dump.txt"
adb push "$OUT/dump.txt" "$W.txt" >/dev/null
adb shell "su -c 'mv $W.txt $W/dump.txt'"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
cat >"$TMP" <<'DEV'
set -u
set -f
W=/data/local/tmp/aot_apps
ART=/apex/com.android.art
BCP=$(echo "$BOOTCLASSPATH")
mkdir -p "$W/empty" "$W/out"
FAILED=
path=
while IFS= read -r l; do
	case $l in
	*"path: "*) path=${l#*path: } ;;
	*"[location is "*)
		loc=${l#*\[location is }; loc=${loc%\]}
		case $loc in /data/dalvik-cache/*) ;; *) continue ;; esac
		[ -f "$loc" ] || continue
		isa=${loc#/data/dalvik-cache/}; isa=${isa%%/*}
		case $path in /system/*|/product/*|/system_ext/*) ;; *) continue ;; esac
		ctx=$($ART/bin/oatdump --header-only --oat-file="$loc" 2>/dev/null | sed -n 's/^classpath = //p' | sed 's/\*[0-9]*//g')
		[ -n "$ctx" ] || ctx="PCL[]"
		case $isa in arm64) d2o=$ART/bin/dex2oat64 ;; *) d2o=$ART/bin/dex2oat32 ;; esac
		b=${path##*/}; dir=${path%/*}
		o=$W/out$dir/oat/$isa/${b%.apk}
		mkdir -p "${o%/*}"
		a="--compiler-filter=speed -j$(nproc) --instruction-set=$isa"
		v=$(getprop "dalvik.vm.isa.$isa.variant"); [ -n "$v" ] && a="$a --instruction-set-variant=$v"
		v=$(getprop "dalvik.vm.isa.$isa.features"); [ -n "$v" ] && a="$a --instruction-set-features=$v"
		echo "[$isa] $path"
		if $d2o $a --android-root=$W/empty --force-determinism --avoid-storing-invocation \
			--generate-mini-debug-info --strip --runtime-arg -Xbootclasspath:$BCP \
			--boot-image=$W/boot/system/framework/boot.art \
			--dex-file="$path" --dex-location="$path" --class-loader-context="$ctx" \
			--oat-file="$o.odex" --oat-location="$dir/oat/$isa/${b%.apk}.odex" \
			--output-vdex="$o.vdex" >"$W/app.log" 2>&1; then :; else
			tail -n 3 "$W/app.log"; rm -f "$o.odex" "$o.vdex"; FAILED="$FAILED $path"
		fi
		;;
	esac
done <"$W/dump.txt"
[ -z "$FAILED" ] || echo "FAILED:$FAILED"
echo DONE
DEV

adb push "$TMP" "$W.sh" >/dev/null
adb shell -T "su -c 'sh $W.sh'" | tee "$OUT/log.txt" || true
grep -q '^DONE$' "$OUT/log.txt" || { echo "ERROR: compile failed, see $OUT/log.txt"; exit 1; }
adb exec-out "su -c 'tar -cf - -C $W/out .'" | tar -xf - -C "$OUT"
adb shell "su -c 'rm -rf $W $W.sh'"
echo "Done: $OUT"
