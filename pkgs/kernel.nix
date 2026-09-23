# SPDX-License-Identifier: GPL-2.0-only
{
  pkgs,
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
      patch = ../. + "/${path}";
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
        name = "tegra194-eqos-nvethernet-tx-defaults";
        patch = ../patches/linux/0004-net-stmmac-tegra194-match-nvethernet-tx-defaults.patch;
      }
      {
        name = "tegra194-eqos-nvethernet-pbl";
        patch = ../patches/linux/0005-arm64-dts-tegra194-match-nvethernet-pbl.patch;
      }
      {
        name = "stmmac-close-reset-irq-window";
        patch = ../patches/linux/0006-net-stmmac-close-reset-irq-window.patch;
      }
    ];
  structuredExtraConfig = import ./kernel-config.nix { inherit (pkgs) lib; };
}
