# SPDX-License-Identifier: MIT
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
    "armbian"
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
  patches = patchSeries.linux ++ patchSeries.nvidia-oot;
  manifest = pkgs.writeText "jetson-nixos-source-manifest.json" (
    builtins.toJSON {
      linux = linuxSource;
      git = lib.genAttrs sourceNames (name: {
        inherit (inputs.${name}) rev narHash;
      });
      inherit submodulePaths;
      patches = patchSeries;
    }
  );
in
assert builtins.length patchSeries.linux == 8;
assert builtins.length patchSeries.nvidia-oot == 15;
assert builtins.length patches == builtins.length (lib.unique patches);
assert lib.all (name: builtins.match "[0-9a-f]{40}" inputs.${name}.rev != null) sourceNames;
pkgs.runCommand "jetson-nixos-source-manifest" { } ''
  # A non-recursive superproject fetch would leave these directories empty.
  ${lib.concatMapStringsSep "\n" (path: ''
    test -n "$(find ${lib.escapeShellArg "${inputs.nvidia-oot}/${path}"} -type f -print -quit)"
  '') submodulePaths}

  ${lib.concatMapStringsSep "\n" (path: ''
    test -s ${lib.escapeShellArg "${inputs.armbian}/${path}"}
  '') patches}

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
