# SPDX-License-Identifier: GPL-2.0-only
{
  description = "Experimental modern-kernel CUDA support for Jetson Xavier on NixOS";

  inputs = {
    # Audited NixOS 26.05 package set.
    nixpkgs.url = "github:NixOS/nixpkgs/f4f698677b11021a8f84f452e23ae9ef2427bec3";

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
      overlay = import ./overlays/default.nix { inherit inputs linuxSource patchSeries; };
    in
    {
      lib = {
        inherit linuxSource patchSeries;
        # Consumers can validate their final NixOS kernel after adding policy.
        mkKernelContract = import ./checks/kernel-contract.nix;
      };

      overlays.default = overlay;
      nixosModules.xavier = import ./modules/xavier.nix { inherit overlay; };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay ];
          };
          targetPkgs = if system == "aarch64-linux" then pkgs else pkgs.pkgsCross.aarch64-multiplatform;
          inherit (targetPkgs.jetson-xavier) kernel nvidia-oot cuda-smoke;
        in
        (import ./pkgs/sources.nix { inherit pkgs inputs linuxSource; })
        // {
          inherit kernel nvidia-oot cuda-smoke;
          firmware = pkgs.jetson-xavier.firmware.combined;
          userspace = pkgs.linkFarm "xavier-headless-userspace" (
            map
              (name: {
                inherit name;
                path = pkgs.jetson-xavier.userspace.${name};
              })
              [
                "l4t-core"
                "l4t-cuda"
                "l4t-3d-core"
                "l4t-gbm"
                "l4t-init"
                "l4tCsv"
                "containerDeps"
              ]
          );
          kernel-config = kernel.configfile;
        }
      );

      checks = forAllSystems (system: {
        uefi-dtb = import ./checks/uefi-dtb.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
        firmware-compression = import ./checks/firmware-compression.nix {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          firmware = inputs.self.packages.${system}.firmware;
        };
        kernel-contract = import ./checks/kernel-contract.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          kernel = inputs.self.packages.${system}.kernel;
        };
        source-manifest = import ./checks/source-manifest.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit inputs linuxSource patchSeries;
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
