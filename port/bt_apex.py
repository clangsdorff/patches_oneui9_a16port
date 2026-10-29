#!/usr/bin/env python3
"""Patch libbluetooth_jni.so inside com.android.bt.apex and rebuild the payload.

Skips VaultKeeper init in the BLE local key path (btif_storage_get_ble_local_key):
the A14 vendor has no matching VaultKeeper HAL. The lib is a single extent in
the ext4 payload, so the bytes are patched in place and the AVB hashtree footer
is regenerated with the AOSP test key. The apex container is left unsigned;
sign it afterwards with apksigner.
"""
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from ext4cat import Ext4  # noqa: E402

LIB = "/lib64/libbluetooth_jni.so"
OLD = bytes.fromhex("8816523948050037")
NEW = bytes.fromhex("881652392a000014")


def main(apex, avbtool, key, out):
    tmp = tempfile.mkdtemp()
    with zipfile.ZipFile(apex) as z:
        z.extractall(tmp)
        infos = z.infolist()
    payload = os.path.join(tmp, "apex_payload.img")

    fs = Ext4(payload)
    size, ext = fs.file(fs.lookup(LIB))
    if len(ext) != 1:
        sys.exit(f"{LIB} is fragmented, in-place patch not supported")
    base = ext[0][1] * fs.bs
    fs.f.close()
    with open(payload, "r+b") as f:
        data = f.read()
        lib = data[base:base + size]
        if lib.count(OLD) != 1:
            sys.exit(f"pattern found {lib.count(OLD)} times in {LIB}")
        off = base + lib.index(OLD)
        f.seek(off)
        f.write(NEW)
    print(f"patched {LIB} at image offset {off:#x}")

    avb = [sys.executable, "-I", avbtool]
    salt = hashlib.sha256(open(os.path.join(tmp, "apex_manifest.pb"), "rb").read()).hexdigest()
    subprocess.run(avb + ["erase_footer", "--image", payload], check=True)
    subprocess.run(avb + ["add_hashtree_footer", "--do_not_generate_fec",
                          "--algorithm", "SHA256_RSA4096", "--hash_algorithm", "sha256",
                          "--key", key, "--prop", "apex.key:com.android.bt",
                          "--salt", salt, "--image", payload], check=True)
    subprocess.run(avb + ["extract_public_key", "--key", key,
                          "--output", os.path.join(tmp, "apex_pubkey")], check=True)

    with zipfile.ZipFile(out, "w") as z:
        for i in infos:
            if i.filename.startswith("META-INF/"):
                continue
            zi = zipfile.ZipInfo(i.filename, date_time=i.date_time)
            zi.compress_type = i.compress_type
            zi.external_attr = i.external_attr
            with open(os.path.join(tmp, i.filename), "rb") as f:
                z.writestr(zi, f.read())
    shutil.rmtree(tmp)
    print("wrote", out)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit("usage: bt_apex.py <com.android.bt.apex> <avbtool.py> <key.pem> <out.apex>")
    main(*sys.argv[1:])
