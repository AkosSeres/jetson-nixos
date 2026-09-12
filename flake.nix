# SPDX-License-Identifier: MIT
{
  description = "Experimental modern-kernel CUDA support for Jetson Xavier on NixOS";

  inputs = {
    # Match infra's audited nixpkgs-homelab package set (NixOS 26.05).
    nixpkgs.url = "github:NixOS/nixpkgs/f4f698677b11021a8f84f452e23ae9ef2427bec3";

    armbian = {
      url = "github:CybrixSystems/armbian-build/b673d05018528b6735408bd777f4e3bf33d5becf";
      flake = false;
    };

    nvidia-oot = {
      # Fetch the committed gitlinks, never the submodules' branch tips.
      url = "git+https://github.com/OE4T/nvidia-kernel-oot.git?ref=wip-r36.5-6.18&rev=3428d01926de97ca8b0f25fe6edd9c76e19472a1&submodules=1";
      flake = false;
    };

    # Source-only inputs: do not apply either upstream default overlay/module.
    jetpack-r36 = {
      url = "github:anduril/jetpack-nixos/98a83b7d737ed636439c7fdc628a875eaf4cce15";
      flake = false;
    };
    jetpack-r35 = {
      url = "github:anduril/jetpack-nixos/cade3c198b8169ee7fd46dbdc283c714d9923951";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      linuxSource = import ./sources/linux.nix;
      patchSeries = import ./sources/patches.nix;
    in
    {
      lib = {
        inherit linuxSource patchSeries;
      };

      packages = forAllSystems (
        system:
        import ./pkgs/sources.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit inputs linuxSource;
        }
      );

      checks = forAllSystems (system: {
        source-manifest = import ./checks/source-manifest.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit inputs linuxSource patchSeries;
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
