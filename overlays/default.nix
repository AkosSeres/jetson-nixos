# SPDX-License-Identifier: MIT
{
  inputs,
  linuxSource,
  patchSeries,
}:
final: prev:
let
  userspaceOverlay = import ./userspace.nix { inherit inputs; } final prev;
  kernel = import ../pkgs/kernel.nix {
    pkgs = final;
    inherit inputs linuxSource patchSeries;
  };
  mkNvidiaOot =
    kernel:
    import ../pkgs/nvidia-oot.nix {
      pkgs = final;
      inherit kernel inputs patchSeries;
    };
in
userspaceOverlay
// {
  jetson-xavier = userspaceOverlay.jetson-xavier // {
    inherit kernel mkNvidiaOot;
    nvidia-oot = mkNvidiaOot kernel;
    cuda-smoke = import ../pkgs/cuda-smoke.nix {
      inherit (final) lib;
      cudaPackages = userspaceOverlay.jetson-xavier.cudaPackages;
    };
  };
}
