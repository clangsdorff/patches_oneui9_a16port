#!/usr/bin/env bash
# Recompile one rebuilt APK with dex2oat "speed" on the device, reusing the
# class loader context of the odex already installed for it.
# Usage: ./app_aot.sh <local.apk> <device apk path> <output dir>
set -euo pipefail
export LC_ALL=C
APK=$1 LOC=$2 OUT=$3
N=$(basename "$LOC" .apk)
DIR=${LOC%/*}
W=/data/local/tmp/app_aot
mkdir -p "$OUT"
adb push "$APK" /data/local/tmp/$N.apk >/dev/null
CTX=$(adb shell "su -c '/apex/com.android.art/bin/oatdump --header-only --oat-file=$DIR/oat/arm64/$N.odex'" | tr -d '\r' | sed -n 's/^classpath = //p' | sed 's/\*[0-9]*//g')
adb shell "su -c 'rm -rf $W; mkdir -p $W/empty; cd $W; /apex/com.android.art/bin/dex2oat64 --compiler-filter=speed -j\$(nproc) --instruction-set=arm64 --instruction-set-variant=\$(getprop dalvik.vm.isa.arm64.variant) --instruction-set-features=\$(getprop dalvik.vm.isa.arm64.features) --android-root=$W/empty --force-determinism --avoid-storing-invocation --generate-mini-debug-info --strip --runtime-arg -Xbootclasspath:\$BOOTCLASSPATH --boot-image=/system/framework/boot.art --zip-fd=7 --zip-location=$LOC 7</data/local/tmp/$N.apk \"--class-loader-context=${CTX:-PCL[]}\" --oat-file=$W/$N.odex --oat-location=$DIR/oat/arm64/$N.odex --output-vdex=$W/$N.vdex'"
adb exec-out "su -c 'cat $W/$N.odex'" > "$OUT/$N.odex"
adb exec-out "su -c 'cat $W/$N.vdex'" > "$OUT/$N.vdex"
adb shell "su -c 'rm -rf $W /data/local/tmp/$N.apk'"
ls -la "$OUT/$N.odex" "$OUT/$N.vdex"
