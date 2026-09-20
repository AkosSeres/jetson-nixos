# SPDX-License-Identifier: GPL-2.0-only
{ pkgs, firmware }:
let
  zstdFirmware = pkgs.compressFirmwareZstd firmware;
  xzFirmware = pkgs.compressFirmwareXz firmware;
in
pkgs.runCommand "xavier-firmware-compression-${firmware.l4tVersion}"
  {
    nativeBuildInputs = [
      pkgs.zstd
      pkgs.xz
    ];
  }
  ''
    # The leaf packages already assert the exact 15 GV11B files and XUSB blob.
    # Compare the combined package and both compression formats to those bytes.
    {
      (cd ${firmware.gv11b}/lib/firmware && find . -type f -printf '%P\n')
      (cd ${firmware.xusb}/lib/firmware && find . -type f -printf '%P\n')
    } | sort > expected-files
    test "$(wc -l < expected-files)" -eq 16

    root=${firmware}/lib/firmware
    (cd "$root" && find . -type f -printf '%P\n') | sort > actual-files
    diff -u expected-files actual-files
    test "$(find "$root" -type l | wc -l)" -eq 1
    test "$(readlink "$root/tegra19x_xusb_firmware")" = nvidia/tegra194/xusb.bin
    test -s "$root/tegra19x_xusb_firmware"
    test -z "$(find -L "$root" -type l -print -quit)"

    while IFS= read -r file; do
      case "$file" in
        gv11b/*) original=${firmware.gv11b}/lib/firmware/"$file" ;;
        nvidia/tegra194/xusb.bin) original=${firmware.xusb}/lib/firmware/"$file" ;;
        *) echo "Unexpected firmware path: $file" >&2; exit 1 ;;
      esac
      test ! -L "$root/$file"
      cmp "$original" "$root/$file"
    done < expected-files

    for format in zstd xz; do
      case "$format" in
        zstd) compressed=${zstdFirmware}/lib/firmware; extension=zst ;;
        xz) compressed=${xzFirmware}/lib/firmware; extension=xz ;;
      esac
      (cd "$compressed" && find . -type f -printf '%P\n') \
        | sed "s/\.$extension\$//" | sort > actual-files
      diff -u expected-files actual-files
      test "$(find "$compressed" -type l | wc -l)" -eq 1
      test "$(readlink "$compressed/tegra19x_xusb_firmware.$extension")" = \
        "nvidia/tegra194/xusb.bin.$extension"
      test -s "$compressed/tegra19x_xusb_firmware.$extension"
      test -z "$(find -L "$compressed" -type l -print -quit)"

      while IFS= read -r file; do
        "$format" -dc "$compressed/$file.$extension" > decoded
        cmp "$root/$file" decoded
      done < expected-files
    done

    cp expected-files "$out"
  ''
