# SPDX-License-Identifier: MIT
# Ordered paths inside the locked Armbian input. This is provenance metadata;
# the patches retain their upstream terms and are applied by the kernel/OOT packages.
let
  linuxRoot = "patch/kernel/archive/uefi-arm64-6.18";
  ootRoot = "extensions/jetson-l4t/files/dkms";
in
{
  linux = map (name: "${linuxRoot}/${name}") [
    "0004-arm64-dts-tegra194-add-nvmap-carveouts-node.patch"
    "0005-arm64-dts-tegra194-add-nvidia-display-node.patch"
    "0006-arm64-dts-tegra194-p2972-rename-thermal-zones.patch"
    "0007-arm64-dts-tegra194-enable-Tj-thermal-zone.patch"
    "0008-arm64-dts-tegra194-relax-eqos-axi-outstanding-limits.patch"
    "0009-memory-tegra186-emc-honor-icc-requests-as-emc-clock-floor.patch"
    "0010-net-stmmac-dwc-qos-request-interconnect-bandwidth-on-tegra.patch"
    "0011-net-stmmac-prevent-indefinite-rx-stall-on-buffer-exhaustion.patch"
    "0012-arm64-dts-tegra194-enable-eqos-multi-queue.patch"
  ];

  # Apply relative to the superproject root, not the Linux source tree.
  nvidia-oot = map (name: "${ootRoot}/${name}") [
    "0006-mc-utils-add-tegra194-support.patch"
    "0007-nv-platform-add-tegra194-display-compatible.patch"
    "0008-g_hal_archimpl-enable-T194-HIDREV.patch"
    "0009-g_chips2halspec-add-T194-HalVarIdx.patch"
    "0010-rmconfig-enable-T194-T19X.patch"
    "0011-g_rmconfig_private-enable-IsT194-IsT19X.patch"
    "0012-g_hal_register-add-T194-registration.patch"
    "0013-kern_gpu_t234d-NVRM-only-for-T194.patch"
    "0014-gpu_t234d_kernel-T194-name-and-addr-width.patch"
    "0015-nv-platform-add-NVRM-only-probe-for-T194.patch"
    "0016-host1x-fence-add-tegra194-to-MODULE_DEVICE_TABLE.patch"
    "0017-mttcan-make-clk-set-parent-non-fatal.patch"
    "0018-nvdisplay-adapt-to-pci_resize_resource-exclude_bars.patch"
    "0019-nvdisplay-conftest-require-crypto_akcipher_verify-for-lkca.patch"
    "0020-tegra-fbdev-adapt-to-preallocated-fb_info.patch"
  ];
}
