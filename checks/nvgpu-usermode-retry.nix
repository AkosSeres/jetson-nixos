# SPDX-License-Identifier: GPL-2.0-only
{ pkgs, source }:
pkgs.runCommand "nvgpu-usermode-retry"
  {
    nativeBuildInputs = [
      pkgs.stdenv.cc
      pkgs.python3
      pkgs.patch
    ];
  }
  ''
    set -o pipefail
    mkdir -p "$out"
    python3 -u ${./nvgpu-usermode-retry.py} \
      ${source} \
      ${../patches/nvgpu/0002-reset-usermode-mapping-retry-error.patch} \
      | tee "$out/test.log"
  ''
