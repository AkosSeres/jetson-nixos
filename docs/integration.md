<!-- SPDX-License-Identifier: MIT -->
# Integration boundaries

These are implementation constraints, not features implemented by this scaffold.

## Ownership

This repository will own reusable source pins, patches, kernel/OOT packaging,
selected userspace/firmware packaging, and an opt-in Xavier NixOS module.

Infra will own host configuration, K3s policy, secrets, boot-generation selection,
and deployment. Consume this project as a locked flake input, not a submodule.
Keep production Xavier outputs unchanged and add separate experimental outputs
only after package-level builds succeed.

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
- llama.cpp should follow the host-selected CUDA package set. Toolchain/compiler
  compatibility still needs a real CUDA build and runtime test.

The headless reference includes an NVRM-only `nvidia.ko` path from the nvdisplay
source. Excluding display as a milestone does not justify dropping every file
whose name contains "display".

## Required decisions during the kernel/module build step

- Establish exactly one provider for host1x, tegra-drm, and BPMP; mainline and OOT
  overlap, including the differently spelled BPMP module names.
- Keep mainline MC/EMC/interconnect support; the OOT private memory Makefile is
  not a substitute.
- Check the generated kernel configuration, including NvMap's requirements for
  `CONFIG_DMA_SHARED_BUFFER=y` and `CONFIG_ARCH_HAS_PMEM_API=y`.
- Derive configuration from actual headless requirements; do not copy the entire
  Armbian board configuration or its installers blindly.
- Do not bring the production Realtek backport into 6.18 by default. Evaluate the
  in-tree driver if a relevant USB adapter is actually needed.
- Follow the local-patch migration decisions in [sources.md](sources.md).
- Update the kernel point release after reproducing the baseline and re-check
  patches and APIs rather than treating 6.18.22 as a deployment recommendation.

## Validation gates

1. Build the kernel, DTB, and OOT modules; inspect configuration, module ownership,
   dependencies, and installed filenames.
2. Build selected firmware/userspace and a real SM 7.2 CUDA/llama.cpp workload.
3. Build a complete experimental infra system with stable configurations intact.
4. Coordinate one test node, recovery access, free boot-partition space, retained
   stable generations, and workloads before any boot change.
5. Boot a coherent kernel/userspace generation. Validate networking, storage,
   USB, thermals/fan control, CUDA, NvMap memcg limits/accounting, and containers,
   then sustained workloads.

Do not use a live switch to mix a new userspace stack with a running old kernel.
Source checks in this repository do not satisfy any of these hardware gates.
