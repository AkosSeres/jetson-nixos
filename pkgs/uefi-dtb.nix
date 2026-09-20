# SPDX-License-Identifier: MIT
{
  pkgs,
  dtbs,
  name,
}:
assert pkgs.lib.assertMsg (
  builtins.isString name
  && name != ""
  && !(pkgs.lib.hasPrefix "/" name)
  && !(builtins.elem ".." (pkgs.lib.splitString "/" name))
) "The Xavier UEFI DTB must have an explicit name relative to the DTB directory.";
pkgs.runCommand "jetson-xavier-uefi-dtbs"
  {
    nativeBuildInputs = [ pkgs.dtc ];
    passthru.paddingBytes = 65536;
  }
  ''
    # NVIDIA's configuration-table notification applies firmware overlays to
    # replacement DTBs in place. A packed tree has no space for these updates;
    # failed libfdt overlay application can invalidate its magic. Reserve space
    # in the FDT totalsize, not merely trailing bytes outside the declared tree.
    # Keep this separate from the kernel so a padding fix never recompiles it.
    source=${pkgs.lib.escapeShellArg "${dtbs}/${name}"}
    dtc -q -I dtb -O dtb -p 65536 -o padded.dtb "$source"

    # Padding must not change nodes, properties, phandles or memory reservations.
    dtc -q -s -I dtb -O dts -o before.dts "$source"
    dtc -q -s -I dtb -O dts -o after.dts padded.dtb
    cmp before.dts after.dts

    cp -rs --no-preserve=mode ${dtbs}/. "$out"
    # install replaces the copied symlink, never writing through to the source.
    install -m 0644 padded.dtb "$out"/${pkgs.lib.escapeShellArg name}
  ''
