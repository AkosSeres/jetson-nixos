# SPDX-License-Identifier: GPL-2.0-only
{
  pkgs,
  inputs,
  linuxSource,
}:
let
  linuxArchive = pkgs.fetchurl {
    inherit (linuxSource) url hash;
  };
in
{
  linux-source = linuxArchive;

  # Fetches sources only. No vendor installers, compilation, or unfree binaries.
  sources = pkgs.linkFarm "jetson-nixos-sources" (
    [
      {
        name = "linux-${linuxSource.version}.tar.xz";
        path = linuxArchive;
      }
      {
        name = "armbian-patches";
        path = ../patches/armbian;
      }
    ]
    ++
      map
        (name: {
          inherit name;
          path = inputs.${name};
        })
        [
          "nvidia-oot"
          "jetpack-r36"
          "jetpack-r35"
        ]
  );
}
