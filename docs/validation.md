<!-- SPDX-License-Identifier: MIT -->
# Validation record and trial boundary

## Build evidence (2026-09-14, implementation in progress)

- Linux was advanced from the hardware-validated 6.18.46 baseline to the current
  6.18.52 longterm point release. The archive hash was checked against the
  kernel.org publisher checksum list. All eight reference and four local Linux
  patches applied, and both the standalone kernel contract and the consuming
  trimmed headless contract passed. The latter contains 611 modular options
  compared with the 7,430-module broad baseline. Kernel/OOT/system compilation
  and runtime validation for 6.18.52 remain pending; evidence below names the
  exact version tested.
- Source revisions, recursive gitlinks and ordered patch presence checked.
- All eight reference Linux patches applied and a strict ARM64 configuration
  generated on 6.18.22, then on 6.18.46.
- The 6.18.46 kernel contract check passed, including NvMap prerequisites,
  exclusive host1x/DRM ownership, BPMP, storage, Ethernet and container support.
  It passed both for the cross-generated configuration and natively on an AGX
  Xavier. This checks configuration, not kernel compilation.
- Fifteen reference OOT patches and all three local nvgpu/ownership/headless
  fixes applied sequentially to one clean source tree.
- Linux 6.18.46, its DTBs and mainline modules built successfully from x86_64
  for ARM64 with a consuming configuration's trimmed headless policy. This does
  not establish that the broader standalone baseline has completed a build.
- The initial OOT build stopped at Make argument parsing. Compiler-command
  quoting and the explicit build target were corrected. The retry compiled
  hwpm and the nvidia-oot objects, then failed modpost on the missing built-in
  `host1x_context_device_bus_type` symbol. The kernel now explicitly selects
  the context bus independently of the external host1x hardware driver;
  its IOMMU integration cannot be replaced by an OOT-only symbol definition.
  The updated kernel and complete OOT stack subsequently cross-built
  successfully for ARM64, including compilation, modpost, installation and
  the mandatory required-module and normalized provider-collision checks.
  The kernel exports the context-bus symbol; nvmap, nvgpu, host1x,
  host1x-fence, host1x-nvhost, tegra-drm and nvidia are present in the output.
  The trimmed kernel and OOT stack also built successfully natively on an AGX
  Xavier. These compilation results alone are not hardware boot tests.
- R35.6.5 firmware extraction built locally and verified all 15 GV11B files,
  Tegra194 XUSB firmware, and its compatibility symlink.
- The selected R36.4.4 driver libraries, init payload, CSV files and container
  dependency tree built natively on an AGX Xavier, together with R35.6.5 firmware.
- The native system build exposed broken external symlinks when NixOS compressed
  the combined firmware package. The combined output now contains real payload
  files and only the relative XUSB compatibility symlink. The new
  `firmware-compression` check passed on x86_64 and natively on an AGX Xavier for
  uncompressed, Zstandard and XZ outputs, comparing all 16 payloads byte-for-byte
  and checking the alias.
- A consuming configuration's complete NixOS system subsequently built
  successfully natively on an AGX Xavier, including the initrd and boot
  specification. Its trimmed kernel required an explicit consumer-side initrd
  module list instead of generic PC defaults; all requested modules resolved
  with missing-module checks enabled. The boot specification references the
  built Linux 6.18.46 image, initrd and P2972 DTB.
- Under a separate staging request, the consuming system's trial boot entry was
  installed and selected as the normal default, preserving the known-good entry.
  Kernel, initrd and DTB copies on the ESP matched their store sources byte for
  byte. Runtime EFI-variable writes were unavailable on the AGX Xavier, so
  one-shot selection could not be used; local console recovery was confirmed
  before selecting the trial default. No reboot or live activation occurred.
- Standalone headless NixOS module evaluated with no failed assertions.
- Sanitized R36 udev rules built natively; the ordered device-node helper passed
  its shell checks. Neither constitutes a device-creation runtime test.
- A consuming NixOS configuration's full udev rules build passed all 11 rule-file
  checks on an AGX Xavier.
- CUDA 12.6 smoke test compiled **natively on an AGX Xavier**, with GCC 13.4 and
  `sm_72`, producing an ARM64 ELF. It was not run against the old kernel.
- A consuming llama.cpp build reached CMake but failed CUDA toolkit discovery.
  Paired native CMake probes reproduced the strict-dependency/discovery-order
  failure and passed with an explicit nvcc compiler path. The corrected full
  build passed configuration and began CUDA compilation, then was cancelled:
  llama.cpp is deferred as optional follow-up work. No successful full llama.cpp
  build or execution is claimed.
- The fan DT patch compiled separately; critical trip thresholds were checked.
- Linux 6.18.51 subsequently built and booted on both Xavier nodes. CUDA, NvMap
  accounting and K3s workloads worked, but sustained network traffic eventually
  caused stmmac TX watchdog resets. A controlled 15-minute retest on the same
  node and workload, changing only TCP TSO to off, completed with the node Ready
  and no new watchdog or adapter reset. Linux 6.18.52 includes the stable
  page-pool teardown fix and this candidate additionally backports upstream
  commit `5e38d732ec67`, which corrects fragmented-TSO descriptor accounting.
  Hardware validation with TSO enabled on that patched kernel is still pending.

These build-only checks do not establish bootability, CUDA runtime compatibility,
thermal behaviour, working CDI devices, or sustained NvMap accounting. The
subsequent bounded hardware checks below are separate evidence.

## Initial boot failure and DTB correction (2026-09-13)

The user subsequently booted the trial, which stopped with an EFI-stub invalid
FDT-header error. The old vendor-kernel generations were recovered using
DeviceTree mode and a cold boot without display/keyboard attached; their boot
failure under other conditions does not establish corruption by the trial.

The staged DTB matched the build output and had a valid header but no free
capacity for firmware updates. A separate packaging step now reserves 64 KiB
after NixOS overlay processing. Its local synthetic-overlay regression and
padding of an already-built mainline DTB passed, preserving canonical tree
contents. The same regression passed natively on an AGX Xavier. The complete
updated closure also built successfully there, rebuilding only the DTB package,
boot metadata and system wrapper. The kernel, initrd, modules, firmware and
userspace inputs were unchanged; production configuration derivations also
remained unchanged. At this stage hardware boot and CUDA execution had not yet
been validated.

Under a subsequent explicit staging request, the padded closure was installed
as a new trial generation. Its 193,890-byte DTB has 65,536 bytes of declared free
capacity; the ESP copy matched the built DTB byte-for-byte, as did kernel and
initrd. The old known-good entry and boot payloads were preserved, and the
running vendor-kernel system was not activated or rebooted. This is a persistent
default selection, not an automatic one-shot rollback.

## Initial headless runtime checks (2026-09-13)

A coordinated AGX Xavier boot with a consuming configuration's trimmed Linux
6.18.46 kernel, the padded mainline DTB, OE4T OOT modules, R36.4.4 driver userspace
and R35.6.5 firmware succeeded. NVMe root, Ethernet, the required GPU modules and
device nodes were present. This does not establish that every configuration
using the broader standalone kernel baseline has been tested.

The same kernel, module, firmware and userspace outputs subsequently booted on a
second AGX Xavier with a host-specific DT overlay. Its NVMe root, factory MAC,
CUDA smoke test, kernel fan policy and cluster workloads also worked.

The already-built `xavier-cuda-smoke` then passed independently as a video-group
user and as root, each with a 30-second timeout. It identified `Xavier`, compute
capability 7.2, allocated 4 MiB, executed an SM 7.2 kernel, synchronized, copied
back and checked all 1,048,576 integer results, and freed the allocation. Both
invocations exited zero. No llama.cpp build or workload was run. The inspected
recent kernel journal showed GPU scaling initialization, with no GPU/IOMMU
fault reported during these bounded checks.

CPU/GPU sensor readings were approximately 40.5-43 C around the smoke tests.
The kernel `step_wise` governor was active; the PWM fan was observed at both
zero and low duty during the surrounding idle period. This is not a thermal
stress test or proof of full-speed cooling at the higher trip points.

The R36.4.4 `nvidia-smi` executable identified `Xavier (nvgpu)`, driver 540.4.0
and CUDA 12.6, but utilization, temperature, power and memory telemetry were
unavailable. A consuming profile placed both `nvidia-smi` and the exported
`l4t-tools` package on the host PATH. A bounded `tegrastats` sample reported RAM,
CPU load/clocks, GPU frequency and temperatures. Vendor `nvfancontrol` and
`nvpmodel` remain intentionally disabled.

The device-node and CDI-generation services were active. An isolated
CUDA-backed ML container ran CLIP, face and OCR inference with all six resident
models. Its 8 GiB cgroup reflected the GPU-backed allocations and triggered
reclaim without an OOM; the operator had observed only a few hundred MiB before
NvMap accounting was implemented. This validates accounting for that workload,
not every allocation path or sustained limit enforcement. TensorRT/cuDNN and
sustained thermal/load testing remain unvalidated.

A consuming profile also enabled the audited firewall and network-policy
modules. Firewall startup, K3s networking, node readiness, and encrypted
Longhorn V1 volumes recovered successfully after boot. Those workload-policy
choices remain outside this reusable repository.

## Before each new kernel trial

1. Complete kernel/OOT compilation and module ownership/dependency inspection.
2. Build the selected driver/container userspace, firmware and CUDA smoke test.
3. Evaluate the consuming trial configuration and verify production outputs
   are unchanged.
4. Build the complete selected trial system without activating it.
5. Coordinate one test node, workload handling, serial/local recovery access,
   its known-good boot entry, and free ESP space before changing boot selection.

Check the EFI system partition's available space; do not assume an unlimited
number of retained kernel/initrd copies will fit. Do not garbage-collect the
known-good generation during the experiment. In a cluster, test one node first.

Use a coherent boot into the new kernel and userspace. A live `switch` while
5.10 is running is not a valid compatibility test or migration path. Installing
a future generation or rebooting requires a separate, explicit deployment task.

## Checks after a coordinated trial boot

- Confirm `uname -r`, board DT identity, NVMe root, ordinary BPMP/clock providers,
  Ethernet/link/IP/SSH/Tailscale, and XUSB; inspect the boot journal for probe,
  firmware, IOMMU, and unresolved-symbol errors.
- Confirm one provider for each required GPU module and expected GPU device
  nodes. Run `xavier-cuda-smoke` as root and as a video-group user.
- Check CPU/GPU thermal-zone readings and fan PWM at idle and under a modest
  supervised CUDA load. Stop testing if cooling or sensor feedback is missing.
- Confirm the matching R36.4 CSV CDI specification includes the actual Xavier
  devices and driver-library closure. Test one GPU container before K3s workloads.
- Verify NvMap allocations are charged to the workload's cgroup, release after
  exit, and respect a controlled memory limit. Then perform sustained tests.

Do not claim TensorRT/cuDNN, display, camera, video acceleration, or production
readiness from these headless tests.

An optional later llama.cpp trial should build it explicitly, exercise a small
known model, and verify GPU offload in its log. It is not a first-boot gate.
