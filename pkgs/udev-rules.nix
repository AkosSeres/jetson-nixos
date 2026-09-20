# SPDX-License-Identifier: GPL-2.0-only
{ pkgs, l4t-init }:
pkgs.runCommand "jetson-xavier-udev-rules"
  {
    meta.license = pkgs.lib.licenses.unfree;
  }
  ''
    rules=${l4t-init}/etc/udev/rules.d/99-tegra-devices.rules
    test -s "$rules"
    mkdir -p "$out/etc/udev/rules.d"
    # Preserve the pinned vendor device permissions and their original license
    # notice. Drop commands: the headless module creates NVRM nodes explicitly,
    # and must not run display/video/camera or vendor power-management helpers.
    sed '/RUN+=/d' "$rules" > "$out/etc/udev/rules.d/99-tegra-devices.rules"
    ! grep -q 'RUN+=' "$out/etc/udev/rules.d/99-tegra-devices.rules"
    grep -q 'nvidia-gpu-v2' "$out/etc/udev/rules.d/99-tegra-devices.rules"
    grep -q 'LicenseRef-NvidiaProprietary' "$out/etc/udev/rules.d/99-tegra-devices.rules"
  ''
