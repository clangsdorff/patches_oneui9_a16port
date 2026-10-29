# patches_oneui9_a16port

Smali patches and port scripts used in a14revive version 5.0 project

One UI 9 (A166BXXUAEZJ5) ported to the Galaxy A14 4G (SM-A145F). Each target
JAR/APK is decoded with apktool, patched, rebuilt and signed with your own key.

## Requirements

- Android SDK build-tools (for `zipalign` and `apksigner`)
- Java (for apktool)
- `apktool.jar`
- Your own platform key: `SIGN_KEY` (pk8) and `SIGN_CERT` (x509 pem)

## Usage

Put the stock A166B files in `apks/`, then:

```sh
SIGN_KEY=platform.pk8 SIGN_CERT=platform.x509.pem ./run_local.sh                 # build every target
SIGN_KEY=platform.pk8 SIGN_CERT=platform.x509.pem ./run_local.sh SecSettings.apk # build one target
```
```sh
./make_patch.sh open   <target>            decode into unpacked/<base>_work/ and snapshot it
./make_patch.sh diff   <target> [out.patch] write the patch from your edits
./make_patch.sh verify <target> [out.patch] fresh decode + git apply --check
./make_patch.sh reset  <target>            throw away edits, back to pristine
./make_patch.sh clean  <target>            delete the work dir

Layout: apks/ inputs, patches/ patch files, unpacked/ work dirs.
```

`services.jar` gets the certificate of `SIGN_CERT` as the platform signature, so
sign the APKs with the same key.

## Port scripts

`port/` holds the rest of the port, applied on the extracted system and product trees:

- `debloat.txt`, `from_target.txt`: files removed from A166B and taken from A145F stock
- `sff.txt`, `system.prop`: floating feature and build.prop overrides
- `recipes/`: the smali edits behind the patches
- `bt_apex.py`: Bluetooth APEX patch
- `files/`: A145F DVFS/SIOP tables, camera feature, blocklist, init scripts

## What gets patched

- **framework.jar / services.jar** – platform signature spoof, CoreRune/Freecess
  device detection, RescueParty off, KnoxPatch, Secure Folder, screenshot and
  screen recording detection off, package blocklist, RAM Plus off by default.
- **knoxsdk.jar / samsungkeystoreutils.jar / KmxService.apk** – Knox integrity
  bypass (Secure Folder, attestation).
- **ssrm.jar / SamsungDeviceHealthManagerService.apk / SohService.apk** – DVFS,
  SIOP and battery tables retargeted to s5e3830 (Exynos 850).
- **SystemUI.apk / BlueLightFilter.apk** – software Eye comfort shield, power-off lock,
  quick panel tiles.
- **SecSettings.apk / SecSettingsIntelligence.apk** – Outdoor mode, Eye comfort
  shield slider, Motion smoothness hidden, deknox settings entries.
- **DAAgent.apk** – Dual Messenger for all apps.
- **Traceur / DeviceDiagnostics / ManagedProvisioning / StorageManager**
  – deknox removals.

## Credits

- [UN1CA](https://github.com/salvogiangri/UN1CA) – signature, dvfs, knoxpatch,
  deknox, blocklist, daagent.
- [ExtremeROM](https://github.com/ExtremeXT/ExtremeROM) – FLAG_SECURE bypass, call recording, Outdoor mode.
