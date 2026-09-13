# SPDX-License-Identifier: MIT
{
  pkgs,
  kernel,
  inputs,
  patchSeries,
}:
let
  inherit (pkgs) lib;

  kernelBuild = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
  kernelSource = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/source";
  kernelModules = "${kernel.modules}/lib/modules/${kernel.modDirVersion}";

  # Reuse the exact compiler selected by buildLinux, adding only the language
  # mode required by this vendor tree.  In particular, do not paper over a
  # compiler mismatch with whichever cc happens to be on PATH.
  kernelCcFlag = lib.findFirst (
    flag: lib.hasPrefix "CC=" flag
  ) (throw "nvidia-oot: kernel.commonMakeFlags has no CC entry") kernel.commonMakeFlags;
  kernelCc = lib.removePrefix "CC=" kernelCcFlag;
  commonMakeFlags = builtins.filter (flag: !(lib.hasPrefix "CC=" flag)) kernel.commonMakeFlags;
in
kernel.stdenv.mkDerivation {
  pname = "nvidia-jetson-oot-modules";
  version = "3428d019-${kernel.modDirVersion}";

  # The flake input is fetched recursively, so the pinned nvidia-oot, nvgpu,
  # nvdisplay, and hwpm gitlinks are all present at their locked revisions.
  src = inputs.nvidia-oot;

  patches = map (path: "${inputs.armbian}/${path}") patchSeries.nvidia-oot ++ [
    ../patches/nvidia-oot/0001-firmware-tegra-make-hv-bpmp-optional.patch
    ../patches/nvidia-oot/0002-headless-suppress-optional-providers.patch
    ../patches/nvgpu/0001-dma-clean-up-failed-system-memory-allocations.patch
  ];
  patchFlags = [ "-p1" ];

  nativeBuildInputs = kernel.moduleBuildDependencies;
  strictDeps = true;
  dontConfigure = true;
  enableParallelBuilding = true;

  hardeningDisable = [
    "bindnow"
    "format"
    "fortify"
    "pic"
    "stackprotector"
  ];

  makeFlags = commonMakeFlags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_PATH=${kernelBuild}"
    "KERNEL_HEADERS=${kernelBuild}"
    "KERNEL_OUTPUT=${kernelBuild}"
    "KERNEL_SRC=${kernelSource}"
    "KBUILD_OUTPUT=${kernelBuild}"
    "MODLIB=$(out)/lib/modules/${kernel.modDirVersion}"

    # CONFIG_TEGRA_HOST1X is deliberately disabled in the in-tree kernel to
    # avoid duplicate host1x.ko/tegra-drm.ko providers.  This make-only value
    # selects the corresponding NVIDIA OOT subdirectories.
    "CONFIG_TEGRA_HOST1X=y"
    "CONFIG_TEGRA_OOT_MODULE=m"
    "NV_OOT_BPMP_SKIP_BUILD=y"
    "NV_OOT_HEADLESS=y"

    "IGNORE_PREEMPT_RT_PRESENCE=1"
    "IGNORE_CC_MISMATCH=1"
    "CXX=${kernel.stdenv.cc}/bin/${kernel.stdenv.cc.targetPrefix}c++"
  ];

  # makeFlags is flattened and split on whitespace by stdenv. Keep the compiler
  # command (including its language-mode flag) in one array element; the same
  # array is reused by the build and install phases.
  preBuild = ''
    if ! grep -Fxq 'CONFIG_TEGRA_HOST1X_CONTEXT_BUS=y' "${kernelBuild}/.config" \
      || ! awk '$2 == "host1x_context_device_bus_type" { found = 1 } END { exit !found }' \
        "${kernelBuild}/Module.symvers"; then
      echo 'nvidia-oot: kernel must supply the built-in host1x context bus and its exported symbol' >&2
      exit 1
    fi
    makeFlagsArray+=(${lib.escapeShellArg "CC=${kernelCc} -std=gnu17"})
  '';

  # stdenv's buildPhase consumes buildFlags, not buildTargets. The vendor
  # Makefile defaults to help, so the modules target must be explicit.
  buildFlags = [ "modules" ];
  installTargets = [ "modules_install" ];
  installFlags = [ "INSTALL_MOD_STRIP=1" ];

  postInstall = ''
    moduleDir="$out/lib/modules/${kernel.modDirVersion}"
    moduleFiles="$TMPDIR/nvidia-oot-module-files"

    find "$moduleDir" -type f \
      \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' -o -name '*.ko.gz' \) \
      -printf '%f\n' > "$moduleFiles"

    normalizedModuleFiles="$TMPDIR/nvidia-oot-normalized-module-files"
    sed -E 's/\.ko(\.(xz|zst|gz))?$//; s/_/-/g' "$moduleFiles" \
      | sort > "$normalizedModuleFiles"

    duplicateModules="$(uniq -d "$normalizedModuleFiles")"
    if test -n "$duplicateModules"; then
      echo "nvidia-oot: duplicate normalized module names within OOT output:" >&2
      printf '%s\n' "$duplicateModules" >&2
      exit 1
    fi

    if ! test -s "$moduleFiles"; then
      echo "nvidia-oot: modules_install produced no kernel modules" >&2
      exit 1
    fi

    for module in nvmap nvgpu host1x host1x-fence host1x-nvhost tegra-drm nvidia; do
      if ! sed -E 's/\.ko(\.(xz|zst|gz))?$//' "$moduleFiles" | grep -Fqx "$module"; then
        echo "nvidia-oot: required module $module was not installed" >&2
        exit 1
      fi
    done

    # Linux normalizes '-' and '_' in module names.  The OOT tegra_bpmp
    # provider must remain absent because the in-tree BPMP driver is retained.
    if grep -Fqx tegra-bpmp "$normalizedModuleFiles"; then
      echo "nvidia-oot: conflicting tegra_bpmp module was installed" >&2
      exit 1
    fi

    # buildLinux installs the mainline module inventories in the separate
    # `modules` output; kernel.dev only receives modules_prepare artifacts.
    mainlineModuleRaw="$TMPDIR/nvidia-mainline-module-raw"
    mainlineModuleFiles="$TMPDIR/nvidia-mainline-module-files"
    : > "$mainlineModuleRaw"
    for inventory in modules.order modules.builtin; do
      if ! test -r "${kernelModules}/$inventory"; then
        echo "nvidia-oot: kernel modules output lacks $inventory" >&2
        exit 1
      fi
      sed -E 's#.*/##; s/\.ko(\.(xz|zst|gz))?$//; s/_/-/g' \
        "${kernelModules}/$inventory" >> "$mainlineModuleRaw"
    done
    sort -u "$mainlineModuleRaw" > "$mainlineModuleFiles"
    mainlineConflicts="$(comm -12 "$normalizedModuleFiles" "$mainlineModuleFiles")"
    if test -n "$mainlineConflicts"; then
      echo "nvidia-oot: OOT/mainline normalized module-name conflicts:" >&2
      printf '%s\n' "$mainlineConflicts" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Pinned NVIDIA Jetson out-of-tree kernel modules";
    homepage = "https://github.com/OE4T/nvidia-kernel-oot";
    license = with lib.licenses; [
      bsd3
      gpl2Only
      mit
    ];
    platforms = [ "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
}
