# SPDX-License-Identifier: GPL-2.0-only
{
  inputs,
}:
final: _prev:
let
  jetpackR36 = inputs.jetpack-r36;
  # Complete Jetson cuBLAS entry from NVIDIA CUDA 12.2 Update 2.
  cublasRelease = builtins.fromJSON (builtins.readFile ../sources/cublas-12.2.5.6.json);

  # This package set is deliberately native aarch64 and isolated. Extending its
  # CUDA database cannot change the caller's package set or unrelated JP5 setups.
  xavierOverlay = xavierFinal: xavierPrev: {
    _cuda = xavierPrev._cuda.extend (
      _cudaFinal: cudaPrev: {
        db = cudaPrev.db // {
          cudaCapabilityToInfo = cudaPrev.db.cudaCapabilityToInfo // {
            "7.2" = cudaPrev.db.cudaCapabilityToInfo."7.2" // {
              # Experimental CUDA 12.9 toolkit on the R36.5.2 driver stack.
              # Keep this SM 7.2 policy override private to this package scope.
              maxCudaMajorMinorVersion = "12.9";
            };
          };
        };

        extensions = cudaPrev.extensions ++ [
          (import (jetpackR36 + "/pkgs/cuda-extensions") {
            inherit (xavierFinal) lib;
          })
          # Experimental older Jetson cuBLAS component, including matching
          # headers and libcublasLt; retain the selected CUDA 12.9 toolkit.
          (
            _cudaFinal: cudaPrev:
            xavierFinal.lib.optionalAttrs (cudaPrev.cudaMajorMinorVersion == "12.9") {
              libcublas = cudaPrev.libcublas.override {
                buildRedist = args: cudaPrev.buildRedist (args // { release = cublasRelease; });
              };
            }
          )
        ];
      }
    );

    nvidia-jetpack-r36_5_2 = import (jetpackR36 + "/mk-overlay.nix") {
      jetpackMajorMinorPatchVersion = "6.2.3";
      l4tMajorMinorPatchVersion = "36.5.2";
      # This describes the BSP's native CUDA generation and selects its
      # packaging helpers. The independently selected toolkit below is 12.9.
      cudaMajorMinorPatchVersion = "12.6.10";
      cudaDriverMajorMinorVersion = "540.5.0";
      bspHash = "sha256-dSMmJkxeFoJtMESnjlmuBhCUZ9N3BRQ7lOZkyRpHH0c=";
      bspPostPatch =
        let
          overlayMb1Bct = xavierFinal.fetchzip {
            url = "https://developer.nvidia.com/downloads/embedded/L4T/overlay_mb1bct_36.x.tbz2";
            hash = "sha256-WdYH5Aoo3JaN7L+dOjTDJDXoyLrWR7tzQBebMIb/KRQ=";
          };
        in
        ''
          cp -r ${overlayMb1Bct}/* .
        '';
    } xavierFinal xavierPrev;

    # jetpack-nixos' CUDA extensions resolve driver dependencies through this
    # alias. Keep it coupled to the exact R36.5.2 scope above.
    nvidia-jetpack = xavierFinal.nvidia-jetpack-r36_5_2;

    # Keep packages reached through cudaPackages.pkgs on the same private
    # toolkit. The BSP scope above retains its own native CUDA 12.6 selector.
    cudaPackages_12 = xavierFinal.cudaPackages_12_9;
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

  r36Scope = xavierPkgs.nvidia-jetpack-r36_5_2;
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

    cudaPackages = xavierPkgs.cudaPackages_12_9;
  };
}
