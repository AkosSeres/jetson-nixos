# SPDX-License-Identifier: MIT
{ pkgs, kernel }:
let
  inherit (pkgs) lib;
  expected = {
    ARM64_4K_PAGES = "y";
    ARM64_PMEM = "y";
    ARCH_HAS_PMEM_API = "y";
    ARCH_TEGRA = "y";
    ARCH_TEGRA_194_SOC = "y";
    TEGRA_HOST1X_CONTEXT_BUS = "y";
    COMMON_CLK = "y";
    TEGRA_BPMP = "y";
    TEGRA_IVC = "y";
    CLK_TEGRA_BPMP = "y";
    RESET_TEGRA_BPMP = "y";
    SOC_TEGRA_POWERGATE_BPMP = "y";
    TEGRA_MC = "y";
    INTERCONNECT = "y";
    STMMAC_ETH = "y";
    STMMAC_PLATFORM = "y";
    DWMAC_DWC_QOS_ETH = "y";
    MARVELL_PHY = "y";
    PCIE_TEGRA194_HOST = "m";
    PHY_TEGRA194_P2U = "m";
    BLK_DEV_NVME = "m";
    USB_XHCI_TEGRA = "m";
    USB_RTL8152 = "m";
    DRM = "y";
    DRM_MIPI_DSI = "y";
    DRM_KMS_HELPER = "y";
    DRM_DISPLAY_HELPER = "m";
    DRM_DISPLAY_DP_HELPER = "y";
    DRM_DISPLAY_HDMI_HELPER = "y";
    PM_DEVFREQ = "y";
    SYNC_FILE = "y";
    DMA_SHARED_BUFFER = "y";
    DMA_CMA = "y";
    CMA_SIZE_MBYTES = "256";
    MEMCG = "y";
    CGROUPS = "y";
    CGROUP_PIDS = "y";
    CGROUP_BPF = "y";
    NAMESPACES = "y";
    NET_NS = "y";
    PID_NS = "y";
    USER_NS = "y";
    OVERLAY_FS = "m";
    VETH = "m";
    VXLAN = "m";
    BRIDGE_NETFILTER = "m";
    NF_CONNTRACK = "m";
    NF_TABLES = "m";
    DM_CRYPT = "m";
    THERMAL_DEFAULT_GOV_STEP_WISE = "y";
    TEGRA_BPMP_THERMAL = "m";
    SENSORS_PWM_FAN = "y";
  };
in
assert kernel.version == "6.18.46";
pkgs.runCommand "xavier-kernel-contract-${kernel.version}" { } ''
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: ''
      if ! grep -Fx 'CONFIG_${name}=${value}' ${kernel.configfile}; then
        echo 'Xavier kernel contract failed: CONFIG_${name}=${value}' >&2
        exit 1
      fi
    '') expected
  )}
  grep -Fx '# CONFIG_TEGRA_HOST1X is not set' ${kernel.configfile}
  grep -Fx '# CONFIG_DRM_TEGRA is not set' ${kernel.configfile}
  cp ${kernel.configfile} "$out"
''
