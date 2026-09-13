# SPDX-License-Identifier: MIT
{
  pkgs,
  source,
}:
let
  inherit (pkgs) lib;

  l4tVersion = "35.6.5";
  # jetpack-nixos records the identical JP5 t194/t234 packages once, under
  # t234, and its R35 scope uses that repository as the default as well.
  sourceRepository = "t234";
  sourceInfo = lib.importJSON (source + "/sourceinfo/r35.6-debs.json");

  gv11bFiles = [
    "NETA_img.bin"
    "NETB_img.bin"
    "NETC_img.bin"
    "NETD_img.bin"
    "acr_ucode_dbg.bin"
    "acr_ucode_prod.bin"
    "fecs.bin"
    "fecs_sig.bin"
    "gpccs.bin"
    "gpccs_sig.bin"
    "gpmu_ucode.bin"
    "gpmu_ucode_desc.bin"
    "gpmu_ucode_image.bin"
    "pmu_bl.bin"
    "pmu_sig.bin"
  ];

  mkDebSource =
    packageName:
    let
      info = sourceInfo.${sourceRepository}.${packageName};
    in
    info
    // {
      src = pkgs.fetchurl {
        url = "https://repo.download.nvidia.com/jetson/${sourceRepository}/${info.filename}";
        hash = "sha256:${info.sha256}";
      };
    };

  firmwareSource = mkDebSource "nvidia-l4t-firmware";
  xusbSource = mkDebSource "nvidia-l4t-xusb-firmware";

  commonMeta = {
    description = "Selected NVIDIA L4T ${l4tVersion} firmware for Jetson AGX Xavier";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryFirmware ];
  };

  commonPassthru = {
    inherit l4tVersion sourceRepository;
  };

  gv11b =
    pkgs.runCommand "xavier-gv11b-firmware-${l4tVersion}"
      {
        nativeBuildInputs = [ pkgs.dpkg ];
        passthru = commonPassthru // {
          sourcePackage = "nvidia-l4t-firmware";
          sourcePackageVersion = firmwareSource.version;
        };
        meta = commonMeta;
      }
      ''
        dpkg-deb -x ${firmwareSource.src} unpacked
        test -d unpacked/lib/firmware/gv11b

        mkdir -p "$out/lib/firmware"
        cp -a unpacked/lib/firmware/gv11b "$out/lib/firmware/"

        test "$(find "$out/lib/firmware/gv11b" -maxdepth 1 -type f | wc -l)" -eq ${toString (builtins.length gv11bFiles)}
        for file in ${lib.escapeShellArgs gv11bFiles}; do
          test -s "$out/lib/firmware/gv11b/$file"
        done
      '';

  xusb =
    pkgs.runCommand "xavier-xusb-firmware-${l4tVersion}"
      {
        nativeBuildInputs = [ pkgs.dpkg ];
        passthru = commonPassthru // {
          sourcePackage = "nvidia-l4t-xusb-firmware";
          sourcePackageVersion = xusbSource.version;
        };
        meta = commonMeta;
      }
      ''
        dpkg-deb -x ${xusbSource.src} unpacked
        test -s unpacked/lib/firmware/nvidia/tegra194/xusb.bin

        install -Dm644 unpacked/lib/firmware/nvidia/tegra194/xusb.bin \
          "$out/lib/firmware/nvidia/tegra194/xusb.bin"
        ln -s nvidia/tegra194/xusb.bin "$out/lib/firmware/tegra19x_xusb_firmware"
        test "$(readlink "$out/lib/firmware/tegra19x_xusb_firmware")" = \
          nvidia/tegra194/xusb.bin
      '';

  combined =
    pkgs.runCommand "xavier-firmware-${l4tVersion}"
      {
        passthru = commonPassthru // {
          inherit gv11b xusb;
        };
        meta = commonMeta;
      }
      ''
        # NixOS compresses regular files and rewrites in-package symlinks. A
        # symlinkJoin points into the uncompressed leaf outputs, where the rewritten
        # .zst/.xz targets do not exist. Keep the payloads in this output instead.
        mkdir -p "$out/lib/firmware"
        cp -a ${gv11b}/lib/firmware/gv11b "$out/lib/firmware/"
        cp -a ${xusb}/lib/firmware/nvidia \
          ${xusb}/lib/firmware/tegra19x_xusb_firmware "$out/lib/firmware/"
      '';
in
{
  scopeName = "l4t-r35_6_5-firmware";
  inherit
    combined
    gv11b
    l4tVersion
    sourceRepository
    xusb
    ;

  sourcePackages = {
    nvidia-l4t-firmware = firmwareSource;
    nvidia-l4t-xusb-firmware = xusbSource;
  };
}
