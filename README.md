<!-- SPDX-License-Identifier: GPL-2.0-only -->
# jetson-nixos

Experimental Nix packaging for a mainline Linux kernel with CUDA on NVIDIA
Jetson AGX Xavier (T194 / GV11B, `sm_72`). This is not an NVIDIA-supported
Xavier BSP.

__Disclaimer: this work is almost fully AI written__

## Status

The Linux 6.18.46 stack has booted on two AGX Xavier systems and has passed CUDA
smoke tests, GPU-container execution, NvMap memory-accounting checks, NVMe-root
operation, Ethernet validation, and basic kernel thermal/fan checks.

The validated EQOS baseline uses four RX/TX queues, a shared MAC interrupt,
NVIDIA-matched DMA and FIFO policy, and the stmmac reset IRQ-window fix. The
recovery path has completed multiple real TX-watchdog resets without the prior
interrupt/RCU/soft-lockup cascade. The underlying rare TX timeout and a separate
RX page-pool teardown leak remain unresolved; see
[the validation record](docs/validation.md) for details.

The selected Linux **6.18.57** stack passed bounded AGX Xavier hardware checks
on **2026-10-16**. The kernel update with R36.4.4/CUDA 12.6 and the subsequent
R36.5.2 userspace update (JetPack 6.2.3, driver 540.5.0) each passed separate
boot, custom CUDA kernel and container checks. It retains the audited OE4T OOT sources,
selected R35.6.5 firmware, upstream stmmac TSO fixes and the carried RX recovery
patch. A follow-up on **2026-10-18** found the fully updated board still on the
same boot after approximately **68 hours** and 131 GB of ordinary Ethernet
traffic, with no recorded TX watchdogs, link drops, GPU faults or memory
exhaustion. Host CUDA and cuBLAS checks passed again. This is evidence for
that observation window; the rare timeout and RX teardown leak remain open.
See [the follow-up record](docs/validation.md#2026-10-18-follow-up-observation).

The following CUDA **12.9** trial passed host and CDI-container SGEMM checks
with PTX JIT disabled, using Jetson nvcc **12.9.86**, cudart **12.9.79**,
compatibility UMD **12.9.40580548**, and the separately pinned Jetson
cuBLAS/cuBLASLt **12.2.5.6** component with matching headers. All 1024 results
passed as an ordinary user, root and in the container. A bounded concurrent
allocation/release preflight also passed. Other math libraries and prolonged
workloads require their own validation; see [validation](docs/validation.md).

The eleven NVIDIA NvMap/nvgpu backports also passed a separate reboot, loaded
module identity checks, host/container SGEMM and bounded allocation/release
checks. These results cover the recorded trial, not a complete security audit.

## Scope

The current project scope is headless CUDA, NVIDIA container integration,
NvMap accounting, NVMe and Ethernet, and kernel thermal/fan control.

Display, camera, hardware video, TensorRT, and cuDNN are not currently
supported or validated by this project.

## Build and check

On a Linux machine with Nix and flakes enabled:

```sh
nix flake check --no-build --all-systems
nix build .#checks.x86_64-linux.source-manifest
nix build .#checks.x86_64-linux.kernel-contract
nix build .#checks.x86_64-linux.uefi-dtb
nix build .#sources
nix build .#nvidia-oot --max-jobs 1 --cores 6
```

On x86_64, `kernel` and `nvidia-oot` cross-build for ARM64. On a Xavier those
outputs build natively. The kernel contract builds and checks the generated
configuration; it does not compile the kernel. `nvidia-oot` builds the kernel,
DTBs, and external modules. It can take considerable time and disk space.

CUDA userspace and `cuda-smoke` are **native aarch64** derivations, even when
evaluated from x86. Build them on a native builder, with modest parallelism on
an in-use Xavier:

```sh
nix build .#userspace .#firmware .#cuda-smoke --max-jobs 1 --cores 2
```

The smoke test allocates 4 MiB on the GPU and verifies a small kernel result.
It does not exercise cuBLAS; require a separate bounded SGEMM check for the
selected library closure. Run tests only with the matching driver/runtime.
Compilation does not prove runtime or math-library compatibility. Build the
separate cuBLAS test and run it with a deadline and PTX JIT disabled:

```sh
nix build .#cuda-cublas-smoke --max-jobs 1 --cores 2
CUDA_DISABLE_PTX_JIT=1 timeout --kill-after=5s 30s result/bin/xavier-cuda-cublas-smoke
```

It verifies a native `sm_72` fill and all 1024 results of a 32x32 SGEMM, and
prints mapped library paths and CUDA API versions. See
[validation](docs/validation.md) for the evidence and remaining gates.

`sources` bundles the pinned sources and vendored patches; it runs no installers.
The firmware and userspace outputs fetch NVIDIA binaries under their own terms.

## NixOS integration

Add the flake as an input and import its Xavier module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    jetson-nixos = {
      url = "github:AkosSeres/jetson-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, jetson-nixos, ... }: {
    nixosConfigurations.xavier = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        jetson-nixos.nixosModules.xavier
        {
          hardware.jetson-xavier.enable = true;
          hardware.jetson-xavier.containers.enable = true;
        }
      ];
    };
  };
}
```

The container option is optional; enable it for matching CSV-based NVIDIA
Container Toolkit integration. The module is limited to the AGX Xavier developer
kit and does not flash firmware.

It owns kernel/DTB/module selection, isolated CUDA 12.9 packages, R36.5.2 driver
libraries, and selected R35.6.5 firmware. The BSP packaging metadata remains
CUDA 12.6.10, independently of the application toolkit and compatibility UMD;
see [integration boundaries](docs/integration.md). OOT owns host1x/tegra-drm;
mainline owns BPMP and MC/EMC. A kernel-managed fan curve replaces vendor nvfancontrol.
The final mainline DTB receives 64 KiB of padding for UEFI updates, after any
NixOS overlays. This does not rebuild the kernel; the initial FDT boot failure
and its correction are recorded in the archived bring-up notes.

Keep hostnames, disks, users, secrets, workload policy and boot selection
in the consuming NixOS configuration. Validate a candidate before promoting it
to normal host outputs, retaining known-good boot generations for recovery.
Use `nixos-rebuild boot` and a coordinated reboot for kernel/driver changes.

To share the consumer's package set, set
`inputs.jetson-nixos.inputs.nixpkgs.follows = "nixpkgs"` (or its host-specific
input name). This also changes the isolated CUDA/userspace package set; validate
the resulting closure. Use `lib.mkKernelContract` to check the final NixOS
kernel after consumer configuration changes.

## Repository layout

- `flake.nix`, `flake.lock`: exact Git inputs and recursive source hashes.
- `sources/linux.nix`: Linux release archive URL and SHA-256.
- `sources/patches.nix`: ordered, repository-relative patch inventories.
- `pkgs/sources.nix`: source-only fetch/bundle outputs.
- `pkgs/kernel*.nix`, `pkgs/nvidia-oot.nix`: kernel/config/module packaging.
- `overlays/`, `pkgs/userspace.nix`, `pkgs/firmware.nix`: isolated package scopes.
- `modules/xavier.nix`: opt-in headless NixOS module.
- `patches/`: local, separately licensed Linux/OOT adaptations.
- `checks/`, `tests/`: source/config checks and the CUDA smoke test.
- [Source provenance](docs/sources.md), [integration boundaries](docs/integration.md),
  and [licensing](docs/licensing.md).

## License

Copyright (c) 2026 Ákos Seres. Original Nix code and documentation are
GPL-2.0-only licensed; see [LICENSE](LICENSE). The CUDA smoke-test program
retains its [MIT license](tests/LICENSE).
Upstream sources and patches retain their own terms. In particular, this license
does not relicense Linux, NVIDIA drivers, CUDA, or firmware. See the
[licensing notes](docs/licensing.md) before importing or distributing artifacts.
