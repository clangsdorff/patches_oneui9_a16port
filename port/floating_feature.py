#!/usr/bin/env python3
"""Build system/etc/floating_feature.xml for the A14 from the A16 one.

Target (A14) values win, except for keys in BLACKLIST, which keep the source
(A16) value. Source-only keys are dropped unless FALLBACK gives them a value.
sff.txt is applied last (KEY=VALUE, empty value deletes the key).
"""
import re
import sys

DEPRECATED = """
SEC_FLOATING_FEATURE_AUDIO_CONFIG_FMRADIO_EXTERNAL_DEVICE
SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_PHASE
SEC_FLOATING_FEATURE_COMMON_CONFIG_DEX_MODE
SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX_ON_PC
SEC_FLOATING_FEATURE_COMMON_SUPPORT_EMBEDDED_SIM
SEC_FLOATING_FEATURE_COMMON_SUPPORT_KNOX_DESKTOP
SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_SCREEN_RECORDER_ITEM
SEC_FLOATING_FEATURE_GALLERY_CONFIG_COLOR_ENGINE_VERSION
SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_DIGITAL_ASSISTANT_WELCOME_V2
""".split()

BLACKLIST = """
SEC_FLOATING_FEATURE_BIXBY_CONFIG_BARGEIN_PARAM_MODE
SEC_FLOATING_FEATURE_CAMERA_CONFIG_MOTIONPHOTO_DEFAULT_SOUND_TIMING
SEC_FLOATING_FEATURE_CAMERA_CONFIG_MOTIONPHOTO_DEFAULT_SOUND_TYPE
SEC_FLOATING_FEATURE_CAMERA_CONFIG_VERSION_FILTER_PROVIDER
SEC_FLOATING_FEATURE_CLOCK_CONFIG_PACKAGE_NAME
SEC_FLOATING_FEATURE_COMMON_CONFIG_WAKEUP_MULTIAGENT_VERSION
SEC_FLOATING_FEATURE_COMMON_DISABLE_NATIVE_AI
SEC_FLOATING_FEATURE_FACTORY_CONFIG_PART_REPLACEMENT_HISTORY
SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_AGENT_WITH_PDE
SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_NOW_NUDGE_VERSION
SEC_FLOATING_FEATURE_GRAPHICS_CONFIG_GAMEBOOSTER_SUICIDE_INTERVAL_MS
SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_GAMEBOOSTER_MANUAL_ROUTINE
SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_GAMEBOOSTER_PERF_MONITOR
SEC_FLOATING_FEATURE_IMS_SUPPORT_UPDATABLE_IMS_SERVICE
SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ZERO_PAGE_PACKAGE_NAMES
SEC_FLOATING_FEATURE_MCF_SUPPORT_CONTINUITY
SEC_FLOATING_FEATURE_MCF_SUPPORT_FRAMEWORK
SEC_FLOATING_FEATURE_SECURITY_SUPPORT_SINK_ITEM
SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_EASY_MODE
""".split()

FALLBACK = {
    "SEC_FLOATING_FEATURE_GRAPHICS_CONFIG_GAME_DEFAULT_FRAMERATE": "60",
    "SEC_FLOATING_FEATURE_GRAPHICS_CONFIG_GAMEBOOSTER_MORE_HEAT": "30",
    "SEC_FLOATING_FEATURE_LCD_CONFIG_PRIVACY_DISPLAY": "0",
    "SEC_FLOATING_FEATURE_LCD_CONFIG_VIVIDNESS": "0",
}

RE = re.compile(r"^\s*<(SEC_FLOATING_FEATURE_[A-Z0-9_]+)>(.*)</\1>\s*$")


def load(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = RE.match(line)
            if m:
                out[m.group(1)] = m.group(2)
    return out


def main(source, target, sff, out):
    src, tgt = load(source), load(target)
    res = {}
    for k, v in src.items():
        if k in DEPRECATED:
            continue
        if k in BLACKLIST:
            res[k] = v
        elif k in tgt:
            res[k] = tgt[k]
        elif k in FALLBACK:
            res[k] = FALLBACK[k]
    for k, v in tgt.items():
        if k not in res and k not in BLACKLIST and k not in DEPRECATED:
            res[k] = v
    with open(sff, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            k, _, v = line.partition("=")
            if not k.startswith("SEC_FLOATING_FEATURE_"):
                sys.exit(f"malformed line in {sff}: {line}")
            if v:
                res[k] = v
            else:
                res.pop(k, None)
    with open(out, "w", encoding="utf-8") as f:
        f.write('﻿<?xml  version="1.0" encoding="UTF-8" ?>\n')
        f.write("<SecFloatingFeatureSet>\n")
        for k in sorted(res):
            f.write(f"    <{k}>{res[k]}</{k}>\n")
        f.write("</SecFloatingFeatureSet>\n")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit("usage: floating_feature.py <source.xml> <target.xml> <sff.txt> <out.xml>")
    main(*sys.argv[1:])
