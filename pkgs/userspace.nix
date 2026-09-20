# SPDX-License-Identifier: GPL-2.0-only
{
  r36Scope,
}:
let
  inherit (r36Scope)
    containerDeps
    l4t-3d-core
    l4t-core
    l4t-cuda
    l4t-gbm
    l4t-gstreamer
    l4t-init
    l4t-multimedia
    l4t-nvfancontrol
    l4t-nvml
    l4t-nvpmodel
    l4t-tools
    l4tCsv
    nvidia-smi
    ;

  driverPackages = [
    l4t-core
    l4t-cuda
    l4t-3d-core
    l4t-gbm
  ];
in
{
  scopeName = "jetpack-r36_4_4";
  inherit (r36Scope)
    cudaDriverMajorMinorVersion
    cudaMajorMinorVersion
    jetpackMajorMinorPatchVersion
    l4tMajorMinorPatchVersion
    ;

  inherit
    containerDeps
    driverPackages
    l4t-3d-core
    l4t-core
    l4t-cuda
    l4t-gbm
    l4t-gstreamer
    l4t-init
    l4t-multimedia
    l4t-nvfancontrol
    l4t-nvml
    l4t-nvpmodel
    l4t-tools
    l4tCsv
    nvidia-smi
    ;

  # These values mirror the coupling in jetpack-nixos' container module while
  # remaining consumable by an independent, opt-in NixOS module.
  containerRuntime = {
    csvFiles = map (fileName: "${l4tCsv}/${fileName}") l4tCsv.fileNames;
    discoveryMode = "csv";
    driverRoot = containerDeps;
    deviceRoot = "/";
    csvIgnorePatterns = [
      "/usr/lib/aarch64-linux-gnu/nvidia/libcuda.so"
    ];
  };
}
