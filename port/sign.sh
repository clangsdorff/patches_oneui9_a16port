#!/usr/bin/env bash
# Sign the rebuilt APKs and the patched Bluetooth APEX with your own key.
#   out/apks/unsigned/*.apk          -> out/apks/signed/*.apk
#   work/bt/com.android.bt.unsigned.apex -> out/apks/signed/com.android.bt.apex
set -e

cd "$(dirname "$0")/.."

SIGN_KEY="${SIGN_KEY:?set SIGN_KEY to your platform pk8}"
SIGN_CERT="${SIGN_CERT:?set SIGN_CERT to your platform x509 pem}"
BT="$(ls -d "$HOME"/Library/Android/sdk/build-tools/* | sort -V | tail -1)"

[ -f "$SIGN_KEY" ] && [ -f "$SIGN_CERT" ] || { echo "[!] $SIGN_KEY or $SIGN_CERT not found"; exit 1; }
mkdir -p out/apks/signed

for f in out/apks/unsigned/*.apk; do
    echo "[*] $(basename "$f")"
    # v4 off: the .idsig makes PackageManager require fs-verity on /system
    "$BT/apksigner" sign --key "$SIGN_KEY" --cert "$SIGN_CERT" \
        --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
        --v4-signing-enabled false \
        --out "out/apks/signed/$(basename "$f")" "$f"
done

if [ -f work/bt/com.android.bt.unsigned.apex ]; then
    echo "[*] com.android.bt.apex"
    # apex_payload.img must stay 4 KiB aligned for apexd
    "$BT/zipalign" -f 4096 work/bt/com.android.bt.unsigned.apex work/bt/com.android.bt.aligned.apex
    "$BT/apksigner" sign --key "$SIGN_KEY" --cert "$SIGN_CERT" \
        --alignment-preserved --align-file-size --v1-signing-enabled true --v2-signing-enabled true \
        --v3-signing-enabled false --v4-signing-enabled false \
        --out out/apks/signed/com.android.bt.apex work/bt/com.android.bt.aligned.apex
    rm -f work/bt/com.android.bt.aligned.apex
fi

echo "[*] done"
