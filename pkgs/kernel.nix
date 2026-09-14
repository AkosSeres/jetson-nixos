# SPDX-License-Identifier: MIT
{
  pkgs,
  inputs,
  linuxSource,
  patchSeries,
}:
pkgs.buildLinux {
  inherit (linuxSource) version;
  modDirVersion = linuxSource.version;
  src = pkgs.fetchurl { inherit (linuxSource) url hash; };
  isLTS = true;
  extraMeta.branch = "6.18";

  # NixOS's common configuration expects its usual automatic module selection.
  # Built-in SoC requirements and OOT ownership are made explicit below.
  defconfig = "defconfig";
  autoModules = true;
  ignoreConfigErrors = false;
  kernelPatches =
    (map (path: {
      name = builtins.baseNameOf path;
      patch = "${inputs.armbian}/${path}";
    }) patchSeries.linux)
    ++ [
      {
        name = "xavier-oot-defconfig";
        patch = ../patches/linux/0001-arm64-defconfig-disable-mainline-tegra-drm.patch;
      }
      {
        name = "xavier-kernel-fan-curve";
        patch = ../patches/linux/0002-arm64-dts-tegra194-p2972-kernel-fan-curve.patch;
      }
      {
        name = "host1x-external-context-bus";
        patch = ../patches/linux/0003-host1x-allow-context-bus-with-external-driver.patch;
      }
      {
        name = "stmmac-tso-descriptor-availability";
        patch = ../patches/linux/0004-net-stmmac-fix-tso-descriptor-availability-check.patch;
      }
      {
        name = "stmmac-tso-dma-mapping-unwind";
        patch = ../patches/linux/0005-net-stmmac-fix-dma-mapping-leak-in-tso-xmit.patch;
      }
    ];
  structuredExtraConfig = import ./kernel-config.nix { inherit (pkgs) lib; };
}
