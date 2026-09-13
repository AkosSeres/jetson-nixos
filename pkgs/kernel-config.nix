# SPDX-License-Identifier: MIT
{ lib }:
with lib.kernel;
{
  # GV11B's downstream interfaces expect a 4 KiB page kernel.
  ARM64_4K_PAGES = lib.mkForce yes;
  ARM64_16K_PAGES = lib.mkForce no;
  ARM64_64K_PAGES = lib.mkForce no;
  ARCH_TEGRA = yes;
  ARCH_TEGRA_194_SOC = yes;
  RUST = lib.mkForce (option no);
  DRM_NOVA = lib.mkForce (option no);
  NOVA_CORE = lib.mkForce (option no);
  DRM_PANIC_SCREEN_QR_CODE = lib.mkForce (option no);

  # BPMP clocks, resets, and power domains are needed before NVMe root mounts.
  TEGRA_IVC = yes;
  TEGRA_BPMP = yes;
  CLK_TEGRA_BPMP = yes;
  SOC_TEGRA_PMC = yes;
  SOC_TEGRA_POWERGATE_BPMP = yes;
  SOC_TEGRA_CBB = yes;
  RESET_TEGRA_BPMP = yes;
  TEGRA186_TIMER = yes;
  TEGRA_HSP_MBOX = yes;
  TEGRA186_GPC_DMA = yes;
  GPIO_TEGRA186 = yes;
  PINCTRL_TEGRA = yes;
  PINCTRL_TEGRA194 = yes;
  ARM_TEGRA186_CPUFREQ = yes;
  ARM_TEGRA194_CPUFREQ = yes;
  ARM_SMMU = yes;
  SRAM = yes;
  OF_OVERLAY = yes;

  SERIAL_TEGRA = yes;
  SERIAL_TEGRA_TCU = yes;
  SERIAL_TEGRA_TCU_CONSOLE = yes;
  I2C_TEGRA = yes;
  I2C_TEGRA_BPMP = yes;
  I2C_CHARDEV = yes;
  I2C_MUX_GPIO = yes;
  I2C_MUX_PCA954x = yes;
  REGULATOR_FIXED_VOLTAGE = yes;
  REGULATOR_GPIO = yes;
  REGULATOR_MAX77620 = yes;
  PINCTRL_MAX77620 = yes;
  GPIO_MAX77620 = yes;
  RTC_DRV_TEGRA = yes;

  # Mainline owns MC/EMC/ICC and Xavier's EQOS Ethernet controller.
  MEMORY = yes;
  TEGRA_MC = yes;
  INTERCONNECT = yes;
  STMMAC_ETH = yes;
  STMMAC_PLATFORM = yes;
  DWMAC_DWC_QOS_ETH = yes;
  MARVELL_PHY = yes;

  PCI = yes;
  PCIE_TEGRA194 = module;
  PCIE_TEGRA194_HOST = module;
  PHY_TEGRA194_P2U = module;
  NVME_CORE = module;
  BLK_DEV_NVME = module;
  MMC = yes;
  RPMB = yes;
  MMC_BLOCK = yes;
  MMC_SDHCI = yes;
  MMC_SDHCI_PLTFM = yes;
  MMC_SDHCI_TEGRA = yes;

  # Load XUSB after firmware is available from the initrd/root filesystem.
  PHY_TEGRA_XUSB = yes;
  USB_XHCI_PLATFORM = yes;
  USB_XHCI_TEGRA = module;
  USB_RTL8152 = module;

  DMA_SHARED_BUFFER = yes;
  ARM64_PMEM = yes;
  # The external stack supplies host1x/tegra-drm, not the in-tree drivers.
  TEGRA_HOST1X = lib.mkForce no;
  DRM_TEGRA = lib.mkForce no;
  # The context bus is separate from host1x.ko and must remain built in for
  # IOMMU bus notifications and the OOT driver's context-device references.
  TEGRA_HOST1X_CONTEXT_BUS = yes;
  DRM = yes;
  DRM_KMS_HELPER = yes;
  DRM_DISPLAY_HELPER = module;
  DRM_MIPI_DSI = yes;
  DRM_DISPLAY_DP_HELPER = yes;
  DRM_DISPLAY_HDMI_HELPER = yes;
  COMMON_CLK = yes;
  PM_DEVFREQ = yes;
  SYNC_FILE = yes;
  DMA_CMA = yes;
  CMA_SIZE_SEL_MBYTES = yes;
  CMA_SIZE_MBYTES = lib.mkForce (freeform "256");
  CMA_ALIGNMENT = freeform "8";
  DEVFREQ_GOV_USERSPACE = yes;
  DEVFREQ_GOV_PERFORMANCE = yes;
  DEVFREQ_GOV_SIMPLE_ONDEMAND = yes;
  DEVFREQ_THERMAL = yes;
  CPU_THERMAL = yes;
  CPU_FREQ_THERMAL = yes;
  CPU_FREQ_GOV_USERSPACE = yes;
  THERMAL_GOV_POWER_ALLOCATOR = yes;
  THERMAL_GOV_USER_SPACE = yes;
  TEGRA_SOCTHERM = module;
  TEGRA_BPMP_THERMAL = module;
  PWM_TEGRA = yes;
  SENSORS_PWM_FAN = yes;
  SENSORS_LM90 = module;
  SENSORS_INA3221 = module;

  # Containers and memory accounting are first-milestone requirements.
  MEMCG = yes;
  CGROUP_HUGETLB = yes;
  OVERLAY_FS = module;
  VETH = module;
  MACVLAN = module;
  IPVLAN = module;
  NETFILTER_XT_MATCH_ADDRTYPE = module;
  FRAME_WARN = lib.mkForce (freeform "2048");
}
