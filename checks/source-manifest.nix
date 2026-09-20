# SPDX-License-Identifier: GPL-2.0-only
{
  pkgs,
  inputs,
  linuxSource,
  patchSeries,
}:
let
  inherit (pkgs) lib;
  sourceNames = [
    "nixpkgs"
    "nvidia-oot"
    "jetpack-r36"
    "jetpack-r35"
  ];
  submodulePaths = [
    "hardware/nvidia/t23x/nv-public"
    "hardware/nvidia/tegra/nv-public"
    "hwpm"
    "kernel-devicetree"
    "nvdisplay"
    "nvethernetrm"
    "nvgpu"
    "nvidia-oot"
  ];
  localLinuxPatches = [
    ../patches/linux/0001-arm64-defconfig-disable-mainline-tegra-drm.patch
    ../patches/linux/0002-arm64-dts-tegra194-p2972-kernel-fan-curve.patch
    ../patches/linux/0003-host1x-allow-context-bus-with-external-driver.patch
    ../patches/linux/0004-net-stmmac-tegra194-match-nvethernet-tx-defaults.patch
    ../patches/linux/0005-arm64-dts-tegra194-match-nvethernet-pbl.patch
  ];
  patches = patchSeries.linux ++ patchSeries.nvidia-oot;
  manifest = pkgs.writeText "jetson-nixos-source-manifest.json" (
    builtins.toJSON {
      linux = linuxSource;
      git = lib.genAttrs sourceNames (name: {
        inherit (inputs.${name}) rev narHash;
      });
      inherit submodulePaths;
      patches = patchSeries;
      localPatches.linux = map (path: builtins.baseNameOf (toString path)) localLinuxPatches;
    }
  );
in
assert builtins.length patchSeries.linux == 9;
assert builtins.length patchSeries.nvidia-oot == 15;
assert builtins.length localLinuxPatches == 5;
assert builtins.length patches == builtins.length (lib.unique patches);
assert lib.all (name: builtins.match "[0-9a-f]{40}" inputs.${name}.rev != null) sourceNames;
pkgs.runCommand "jetson-nixos-source-manifest" { } ''
  # A non-recursive superproject fetch would leave these directories empty.
  ${lib.concatMapStringsSep "\n" (path: ''
    test -n "$(find ${lib.escapeShellArg "${inputs.nvidia-oot}/${path}"} -type f -print -quit)"
  '') submodulePaths}

  ${lib.concatMapStringsSep "\n" (path: ''
    test -s ${lib.escapeShellArg "${../. + "/${path}"}"}
  '') patches}

  ${lib.concatMapStringsSep "\n" (path: ''
    test -s ${path}
  '') localLinuxPatches}

  test -s ${../patches/armbian/LICENSE}
  test -s ${../patches/armbian/NOTICE}
  test -s ${../patches/armbian/nvidia-oot/COPYING}
  test -s ${inputs.nvidia-oot}/Makefile
  test -s ${inputs.nvidia-oot}/nvidia-oot/drivers/video/tegra/nvmap/nvmap_alloc.c
  test -s ${inputs.nvidia-oot}/nvgpu/drivers/gpu/nvgpu/os/linux/linux-dma.c
  test -s ${inputs.nvidia-oot}/nvdisplay/kernel-open/nvidia/nv-pci.c
  test -s ${inputs.jetpack-r36}/mk-overlay.nix
  test -s ${inputs.jetpack-r36}/sourceinfo/r36.4-debs.json
  test -s ${inputs.jetpack-r36}/sourceinfo/r36.4.4-gitrepos.json
  test -s ${inputs.jetpack-r36}/pkgs/containers/r36-l4t.json
  test -s ${inputs.jetpack-r35}/sourceinfo/r35.6-debs.json
  test -s ${inputs.jetpack-r35}/sourceinfo/r35.6.5-gitrepos.json

  mkdir -p "$out"
  cp ${manifest} "$out/manifest.json"
''
