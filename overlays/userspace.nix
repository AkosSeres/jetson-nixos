# SPDX-License-Identifier: GPL-2.0-only
{
  inputs,
}:
final: _prev:
let
  jetpackR36 = inputs.jetpack-r36;

  # This package set is deliberately native aarch64 and isolated. Extending its
  # CUDA database cannot change the caller's package set or unrelated JP5 setups.
  xavierOverlay = xavierFinal: xavierPrev: {
    _cuda = xavierPrev._cuda.extend (
      _cudaFinal: cudaPrev: {
        db = cudaPrev.db // {
          cudaCapabilityToInfo = cudaPrev.db.cudaCapabilityToInfo // {
            "7.2" = cudaPrev.db.cudaCapabilityToInfo."7.2" // {
              # The community Xavier demonstration uses CUDA 12.6 despite
              # nixpkgs' conservative stock JetPack ceiling of 12.2 for SM 7.2.
              maxCudaMajorMinorVersion = "12.6";
            };
          };
        };

        extensions = cudaPrev.extensions ++ [
          (import (jetpackR36 + "/pkgs/cuda-extensions") {
            inherit (xavierFinal) lib;
          })
        ];
      }
    );

    nvidia-jetpack-r36_4_4 = import (jetpackR36 + "/mk-overlay.nix") {
      jetpackMajorMinorPatchVersion = "6.2.1";
      l4tMajorMinorPatchVersion = "36.4.4";
      cudaMajorMinorPatchVersion = "12.6.10";
      cudaDriverMajorMinorVersion = "540.4.0";
      bspHash = "sha256-ps4RwiEAqwl25BmVkYJBfIPWL0JyUBvIcU8uB24BDzs=";
      bspPostPatch =
        let
          overlayMb1Bct = xavierFinal.fetchzip {
            url = "https://developer.nvidia.com/downloads/embedded/L4T/r36_Release_v4.4/overlay_mb1bct_36.4.4.tbz2";
            hash = "sha256-QWktb8/cZg9ch7IZ3GRnsLuhU9dD1rYrogBeQvWCg2E=";
          };
        in
        ''
          cp -r ${overlayMb1Bct}/* .
        '';
    } xavierFinal xavierPrev;

    # jetpack-nixos' CUDA extensions resolve driver dependencies through this
    # alias. Keep it coupled to the exact R36.4.4 scope above.
    nvidia-jetpack = xavierFinal.nvidia-jetpack-r36_4_4;

    # Packages reached through cudaPackages.pkgs must see this release as the
    # isolated default too. Leaving nixpkgs' CUDA 12.9 aliases in place makes
    # ordinary R36 driver derivations evaluate that unsupported package set.
    cudaPackages_12 = xavierFinal.cudaPackages_12_6;
    cudaPackages = xavierFinal.cudaPackages_12;
  };

  xavierPkgs = import inputs.nixpkgs {
    system = "aarch64-linux";
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "7.2" ];
    };
    overlays = [ xavierOverlay ];
  };

  r36Scope = xavierPkgs.nvidia-jetpack-r36_4_4;
in
{
  jetson-xavier = {
    userspace = import ../pkgs/userspace.nix {
      inherit r36Scope;
    };

    firmware = import ../pkgs/firmware.nix {
      pkgs = final;
      source = inputs.jetpack-r35;
    };

    cudaPackages = xavierPkgs.cudaPackages_12_6;
  };
}
