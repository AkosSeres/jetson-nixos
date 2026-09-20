# SPDX-License-Identifier: MIT
{ pkgs }:
let
  name = "nvidia/tegra194-p2972-0000.dtb";
  fixture = pkgs.runCommand "xavier-uefi-dtb-fixture" { nativeBuildInputs = [ pkgs.dtc ]; } ''
    mkdir -p "$out/nvidia"
    dtc -I dts -O dtb -o "$out/${name}" ${pkgs.writeText "xavier-uefi-dtb-fixture.dts" ''
      /dts-v1/;
      /memreserve/ 0x80000000 0x1000;
      / {
        compatible = "nvidia,p2972-0000", "nvidia,tegra194";
        chosen { test-string = "preserve me"; test-cells = <1 2 3>; };
        firmware { uefi { }; };
      };
    ''}
    cp "$out/${name}" "$out/nvidia/other.dtb"
  '';
  # Exercise the same post-overlay boundary used by the NixOS module. This
  # synthetic overlay is not NVIDIA firmware and is not a hardware boot test.
  overlaid = pkgs.deviceTree.applyOverlays fixture [
    {
      name = "test-overlay";
      filter = "tegra194-p2972-0000.dtb";
      dtboFile = pkgs.deviceTree.compileDTS {
        name = "xavier-uefi-dtb-test-overlay";
        dtsFile = pkgs.writeText "xavier-uefi-dtb-test-overlay.dts" ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "nvidia,p2972-0000";
            fragment@0 {
              target-path = "/chosen";
              __overlay__ { test-overlay = "preserve this too"; };
            };
          };
        '';
      };
    }
  ];
  padded = import ../pkgs/uefi-dtb.nix {
    inherit pkgs name;
    dtbs = overlaid;
  };
in
pkgs.runCommand "xavier-uefi-dtb-padding"
  {
    nativeBuildInputs = [ pkgs.dtc ];
  }
  ''
    original=${overlaid}/${name}
    padded=${padded}/${name}
    test ! -L "$padded"
    test -z "$(find -L ${padded} -type l -print -quit)"
    cmp ${overlaid}/nvidia/other.dtb ${padded}/nvidia/other.dtb

    dtc -q -s -I dtb -O dts -o original.dts "$original"
    dtc -q -s -I dtb -O dts -o padded.dts "$padded"
    cmp original.dts padded.dts
    test "$(fdtget -t s "$padded" /chosen test-overlay)" = "preserve this too"

    # FDT header words are big-endian. Check actual in-header free space and
    # file length, not just the presence of zeroes appended outside totalsize.
    word() { od --endian=big -An -tu4 -j "$2" -N 4 "$1" | tr -d ' '; }
    total=$(word "$padded" 4)
    strings_offset=$(word "$padded" 12)
    strings_size=$(word "$padded" 32)
    test "$((total - strings_offset - strings_size))" -eq 65536
    test "$(stat -c %s "$padded")" -eq "$total"
    test "$(word "$original" 4)" -lt "$total"
    touch "$out"
  ''
