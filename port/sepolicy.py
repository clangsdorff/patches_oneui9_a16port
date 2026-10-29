#!/usr/bin/env python3
"""Drop system_ext sepolicy types the target vendor does not know about.

Same rules as UN1CA's selinux patch: for each entry present in the
system_ext mapping of the vendor's API level but missing from the vendor
plat_pub_versioned.cil, remove its mapping lines and genfscon rules.
Duplicated property contexts are removed from the system_ext side.
"""
import os
import re
import sys

ENTRIES = """
heatmap_default heatmap_default_exec
attiqi_app attiqi_app_data_file ker_app kpp_app kpp_data_file
hal_dsms_default hal_dsms_default_exec proc_compaction_proactiveness sbauth sbauth_exec
audiomirroring audiomirroring_exec audiomirroring_service fabriccrypto fabriccrypto_exec
fabriccrypto_data_file hal_dsms_service uwb_regulation_skip_prop
""".split()

DUPLICATES = ["init.svc.vendor.wvkprov_server_hal"]


def rewrite(path, keep):
    with open(path) as f:
        lines = f.readlines()
    new = [l for l in lines if keep(l)]
    if len(new) != len(lines):
        with open(path, "w") as f:
            f.writelines(new)
    return len(lines) - len(new)


def main(system, vendor):
    sysext = os.path.join(system, "system", "system_ext")
    ver = open(os.path.join(vendor, "etc/selinux/plat_sepolicy_vers.txt")).readline().strip()
    mapdir = os.path.join(sysext, "etc/selinux/mapping")
    mapping = os.path.join(mapdir, f"{ver}.cil")
    apis = sorted({f[:-4].replace(".", "_", 1) for f in os.listdir(mapdir)
                   if f.endswith(".cil") and ".compat." not in f})
    pub = open(os.path.join(vendor, "etc/selinux/plat_pub_versioned.cil")).read()
    plat = os.path.join(system, "system/etc/selinux/plat_sepolicy.cil")
    sysext_pol = os.path.join(sysext, "etc/selinux/system_ext_sepolicy.cil")

    for e in ENTRIES:
        text = open(mapping).read()
        if f"({e})" not in text and f"{e}_{ver.replace('.', '_')}" not in text:
            continue
        if f"(type {e})" in pub:
            continue
        names = [f"{e}_{a}" for a in apis]
        n = rewrite(mapping, lambda l: f"({e})" not in l and not any(x in l for x in names))
        g = re.compile(rf"genfscon.*\b{re.escape(e)}\b")
        for p in (sysext_pol, plat):
            n += rewrite(p, lambda l: not g.search(l))
        print(f"{e}: removed {n} lines")

    vprops = open(os.path.join(vendor, "etc/selinux/vendor_property_contexts")).read()
    sprops = os.path.join(sysext, "etc/selinux/system_ext_property_contexts")
    for e in DUPLICATES:
        if re.search(rf"^{re.escape(e)}", vprops, re.M):
            n = rewrite(sprops, lambda l: not l.startswith(e))
            if n:
                print(f"{e}: removed {n} duplicate lines from system_ext")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: sepolicy.py <system_tree> <target_vendor_dir>")
    main(*sys.argv[1:])
