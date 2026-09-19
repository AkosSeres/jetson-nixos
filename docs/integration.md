<!-- SPDX-License-Identifier: MIT -->
# Integration boundaries

These are the implementation boundaries for the experimental headless port.

## Ownership

This repository owns reusable source pins, patches, kernel/OOT packaging,
selected userspace/firmware packaging, and an opt-in Xavier NixOS module.

Consuming configurations own host configuration, K3s policy, secrets,
boot-generation selection, and deployment. Consume this project as a locked
flake input.
Keep production Xavier outputs unchanged. Experimental outputs are separate;
their existence does not imply that the validation gates below have passed.

## Stack separation

- Linux 6.18 and its patched mainline T194 DTB are independent of JetPack's kernel.
- Build the OE4T R36.5 OOT superproject against that exact kernel's configuration,
  headers, compiler, and symbol versions.
- Reuse the pinned R36.4 JetPack packaging through a uniquely named package scope,
  not its full default overlay or NixOS module.
- Select R35.6.5 GV11B and XUSB firmware explicitly. Do not import a whole legacy
  module or allow newer Orin firmware to win by package order.
- R36.4 userspace CSV/container dependencies must come from the same R36.4 scope,
  not the newer R36.5 packages also present in the firmware source input.
- Preserve the Xavier `sm_72` target and native Jetson aarch64 CUDA package
  selection. The nixpkgs CUDA 12.6/SM 7.2 policy override must be experimental and
  scoped; do not modify production CUDA or claim an SM 8.7 GPU.
- Optional llama.cpp builds should follow the host-selected CUDA package set. Toolchain/compiler
  compatibility still needs a real CUDA build and runtime test.

For CMake consumers with strict dependency isolation, keep nvcc in native build
inputs and CUDA libraries in host build inputs. If the project calls
`find_package(CUDAToolkit)` before enabling the CUDA language, explicitly select
`CMAKE_CUDA_COMPILER` from `cudaPackages.cuda_nvcc`. The setup hook's split
library roots intentionally exclude the native compiler; they are not a single
monolithic toolkit directory. Do not disable dependency isolation to work around
compiler discovery.

The headless reference includes an NVRM-only `nvidia.ko` path from the nvdisplay
source. Excluding display as a milestone does not justify dropping every file
whose name contains "display".

The module uses the pinned R36 device-permission rules without their executable
actions. A separate ordered service creates `/dev/nvidiactl` and `/dev/nvidia0`
after module loading, checking the registered frontend major and refusing to
replace unexpected paths. This is necessary because the NVRM frontend does not
create those nodes through the kernel device model. Video-group access does not
grant access to the vendor's separate debug/scheduler interfaces. CSV generation
requires the node service; creating the nodes alone does not prove a working GPU.

## Provider and configuration contract

- OOT owns host1x and tegra-drm. Disable both in mainline Kconfig and supply
  `CONFIG_TEGRA_HOST1X=y` only to the external make invocation. Preserve the
  external host1x firewall explicitly.
- Keep `CONFIG_TEGRA_HOST1X_CONTEXT_BUS=y` in the kernel. This small built-in
  bus is not the host1x hardware driver: the OOT driver references its exported
  symbol, and the IOMMU core must include it in its bus notifications. A local
  Kconfig patch permits selecting it without the in-tree host1x driver.
- Mainline owns ordinary BPMP, built in with its clocks/resets/power domains.
  Omit OOT's hypervisor-only `tegra_bpmp` module (its name normalizes to the same
  module name as mainline's `tegra-bpmp`). Keep the independent `ivc_ext` module.
- Keep mainline MC/EMC/interconnect support; the OOT private memory Makefile is
  not a substitute.
- Exclude optional OOT camera, audio, SPI, VSE/SE and CEC providers in the headless
  build. Check normalized installed module names against the mainline inventory;
  Linux treats hyphens and underscores as equivalent in module names.
- `checks/kernel-contract.nix` checks the generated configuration, including
  NvMap's DMA shared-buffer/PMEM/CMA dependencies, DRM helpers, storage, Ethernet,
  namespaces, cgroups and container networking. `ARM64_PMEM` selects
  `ARCH_HAS_PMEM_API`. Use 4 KiB pages.
- Derive configuration from actual headless requirements; do not copy the entire
  Armbian board configuration or its installers blindly.
- Do not bring the production Realtek backport into 6.18 by default. Evaluate the
  in-tree driver if a relevant USB adapter is actually needed.
- Follow the local-patch migration decisions in [sources.md](sources.md).
- The reusable baseline is pinned to the hardware-validated Linux 6.18.46.
  Point-release updates are separate experiments: check patch applicability,
  build outputs, bootability, CUDA, networking and sustained traffic explicitly.
  This is not a rolling security pin.

## Thermal and power policy

Do not enable vendor nvpmodel or nvfancontrol: their libjetsonpower interfaces
are missing in mainline. Use ordinary CPU/devfreq policy and kernel thermal
control. The local DT patch gives CPU and GPU active fan trips that can reach
full fan speed at 75 C while leaving all critical shutdown trips intact. No
userspace thermal governor, clock pinning, or automatic overclocking is enabled.
Actual cooling behaviour is a required first-boot check.

## UEFI device-tree handoff

Use the patched mainline P2972 DTB with the firmware's DeviceTree mode. The
vendor JetPack 5 DTB is not a drop-in replacement for mainline driver bindings.
Unlike a boot using the firmware-supplied tree, a bootloader's explicit
`devicetree` entry installs a replacement tree that firmware may modify.

The module adds 64 KiB of padding to the selected DTB's declared FDT size, after
NixOS filtering and overlay application. Padding before overlays is insufficient
because overlay tools may repack the result. This is a separate packaging step:
it does not rebuild the kernel or OOT modules, alter device-tree properties, or
replace firmware. Each build compares canonical DTS before and after padding.
The `uefi-dtb` check verifies overlay preservation, header capacity and file size.

This addresses the zero-capacity replacement-DTB defect observed during the
initial trial. A subsequent coordinated boot with the padded tree succeeded;
the precise firmware failure mechanism remains inferred from source and the
matching community report, not captured in a serial trace on the test device.
See [source evidence](sources.md#uefi-dtb-padding).
Use serial for boot diagnostics where possible: attached display/USB peripherals
have interfered with otherwise working vendor-kernel boots. Do not infer that
ACPI is the right mode for this port merely because an ACPI installer boots.

## Validation gates

1. Build the kernel, DTB, and OOT modules; inspect configuration, module ownership,
   dependencies, and installed filenames.
2. Build selected firmware/userspace and the SM 7.2 CUDA smoke test.
   llama.cpp is optional follow-up work, not a gate for the initial milestone.
3. Build a complete experimental NixOS system with stable configurations intact.
4. Coordinate one test node, recovery access, free boot-partition space, retained
   stable generations, and workloads before any boot change.
5. Boot a coherent kernel/userspace generation. Validate networking, storage,
   USB, thermals/fan control, CUDA, NvMap memcg limits/accounting, and containers,
   then sustained workloads.

Do not use a live switch to mix a new userspace stack with a running old kernel.
Source checks in this repository do not satisfy any of these hardware gates.
