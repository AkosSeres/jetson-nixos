<!-- SPDX-License-Identifier: GPL-2.0-only -->
# Baseline and validation records

## Selected maintenance release

Linux 6.18.57 is the selected kernel release. Exact source pins are in
[sources.md](sources.md). It uses OE4T OOT revision `3428d019`, R36.5.2 driver
userspace, CUDA 12.9 targeting Xavier's Volta `sm_72` GPU, and R35.6.5
GV11B/XUSB firmware. The selected toolkit includes nvcc 12.9.86 and cudart
12.9.79, compatibility UMD 12.9.40580548 for applications, and the complete
Jetson cuBLAS/cuBLASLt 12.2.5.6 component with matching headers.
The staged hardware trial below records bounded boot, CUDA and container
successes on 2026-10-16, followed by approximately 68 hours of observation on
one updated AGX Xavier through 2026-10-18. The earlier 6.18.46 baseline was
tested on two boards; its observations are retained separately. The additional eleven NVIDIA NvMap/nvgpu backports also
passed their separate boot and bounded regression checks.

The kernel-only trial retained R36.4.4/CUDA 12.6. The next trial booted R36.5.2
userspace (JetPack 6.2.3, driver 540.5.0) with CUDA 12.6 before the CUDA 12.9
stage. Each used a complete matching driver-library and CSV/container closure.
The BSP packaging selector remains CUDA 12.6.10, while CUDA application
RUNPATHs select `cuda_compat` 12.9.40580548 ahead of the system driver link.
Record `cudaDriverGetVersion`, `cudaRuntimeGetVersion` and mapped
`libcuda`, cudart, cuBLAS and cuBLASLt paths. Matching driver package derivations
alone do not identify the UMD loaded by an application.

### CUDA library preflight

Isolated SGEMM tests on the R36.5.2 trial distinguish the custom kernel/runtime
from math-library support. Each failed trial passed allocation and a native
`sm_72` fill before reaching `cublasCreate`:

| Compiler/runtime | cuBLAS payload | Mapped UMD / driver API | `cublasCreate` / SGEMM |
| --- | --- | --- | --- |
| CUDA 12.6 | Jetson 12.6.4.1 | compat 12.6 / 12060 | status 8, `ARCH_MISMATCH` |
| CUDA 12.9 | Jetson 12.9.1.4 | compat 12.9 / 12090 | status 8, `ARCH_MISMATCH` |
| CUDA 12.9 | Jetson 12.9.1.4 | native R36.5.2 / 12060 | status 8, `ARCH_MISMATCH` |
| CUDA 12.9 | SBSA 12.9.1.4 | compat 12.9 / 12090 | status 3, `ALLOC_FAILED` |
| CUDA 12.9 | selected Jetson 12.2.5.6 | compat 12.9 / 12090 | passed; all 1024 SGEMM results |

The SBSA trial failed as both the ordinary user and root, with PTX JIT disabled
and allowed. Available system RAM and the lack of kernel errors did not resolve
initialization. Status 3 alone does not establish a RAM shortage, a CPU ISA
incompatibility or the exact internal failure; that alternative was not
promoted. Its `sm_70` cubins also do not by themselves establish Tegra `sm_72`
compatibility under NVIDIA's
[binary compatibility guidance](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#binary-compatibility).

Original-payload inspection finds no Volta code in Jetson cuBLAS 12.6/12.9,
while both selected Jetson 12.2.5.6 libraries contain native `sm_72` cubins.
The CUDA 12.6 cuBLAS failure is a pre-existing coverage limit hidden by the
custom-kernel smoke; it is not a CUDA 12.9 regression. Separate bounded CUDA
12.9 allocation/free and result checks passed, supporting runtime/allocator
health without establishing cuBLAS support.

The selected mixed component passed `cuda-cublas-smoke` after the CUDA-stage
boot, as an ordinary user, root and in a CDI container. With an external
deadline and `CUDA_DISABLE_PTX_JIT=1`, native `sm_72` execution and all 1024
results of a 32x32 SGEMM passed. Mapped cuBLAS/cuBLASLt/cudart/libcuda paths and
API versions identified the selected libraries. Other libraries, newer cuBLAS
APIs, PTX/JIT and driver features require separate tests; one SGEMM pass does
not establish that coverage.

The update incorporates upstream stmmac maintenance relevant to the enabled TSO
path:

- [6.18.53 TX descriptor accounting fix](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?id=c28175220f808c867d5618de8ecc6dbcc815c773)
  counts the descriptors required by fragmented TSO packets, including headers
  and an MSS context, before accepting a packet. The earlier estimate could
  overwrite descriptors still owned by DMA.
- [6.18.57 DMA mapping cleanup fix](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?id=8a3257f142ae513d0c96d42f97386d4941bcec29)
  releases mappings and descriptors already allocated for a TSO packet when a
  later fragment cannot be mapped.

These fixes justify testing the maintenance update; they do not establish the
cause of the recorded rare TX timeout or resolution of the RX page-pool
teardown leak. The carried RX refill recovery patch has a context-only rebase
for 6.18.57, documented in [the patch provenance](../patches/armbian/README.md).

## 2026-10-16 staged hardware trial

A coordinated AGX Xavier trial completed the following stages in order. The
CUDA-stage boot returned by 01:15:15 UTC, and the running and booted generations
matched the selected complete system. The backport-stage boot returned by
01:26:42 UTC, also with the expected complete system. Both bounded core checks
reported no failed conditions or diagnostic warnings.

| Stage | Kernel / userspace / toolkit | Observed result |
| --- | --- | --- |
| Kernel maintenance | Linux 6.18.57 / R36.4.4 / CUDA 12.6 | Boot, core hardware, custom CUDA kernel and container checks passed |
| R36 userspace | Linux 6.18.57 / R36.5.2, driver 540.5.0 / CUDA 12.6 | Boot, core hardware, custom CUDA kernel and container checks passed |
| CUDA toolkit and selected cuBLAS | Linux 6.18.57 / R36.5.2 / CUDA 12.9, Jetson cuBLAS 12.2.5.6 | Boot and core checks passed; persistent SGEMM test passed as ordinary user, root and in a CDI container, with PTX JIT disabled |
| Eleven NVIDIA NvMap/nvgpu backports | Same selected kernel and userspace | Native module and complete-system builds, separate boot, loaded-module identity, host/root/CDI SGEMM and allocation/release checks passed |

The CUDA allocation/release preflight used two processes, each with 2 MiB of
explicit device allocations over six rounds: 12 allocation/free pairs and
3,145,728 verified integer values per worker. It finished in 0.937 seconds
under a 25-second controller deadline. NvMap reported 64,024,576 bytes per test
client, including context/internal allocations; both test clients' charges
disappeared after their processes exited. This establishes bounded accounting
and release for that test, not every limit or allocator error path. Repeating
the same probe after booting the eleven backports passed in 0.968 seconds,
with the same per-client residency and no test-client charges after exit.
The loaded NvMap/nvgpu GNU build-ID notes matched the exact backport module
files. No new GPU/MMU fault was observed after the bounded compute probes;
malformed ioctls and complete security coverage were not tested.

These results cover the recorded trial and selected library combination.
The follow-up below adds ordinary workload and Ethernet observation; other
CUDA math libraries, TensorRT and cuDNN remain outside this evidence. The
separate stmmac RX page-pool teardown leak remains unfixed.

## 2026-10-18 follow-up observation

A read-only follow-up at approximately **21:40 UTC on 2026-10-18** found the
updated AGX Xavier still running the exact complete-system generation booted
on **2026-10-16 at 01:26 UTC**, approximately **68 hours** earlier. It included
Linux 6.18.57, R36.5.2, CUDA 12.9 with the selected cuBLAS 12.2.5.6 component,
and all eleven NvMap/nvgpu backports.

- Current, booted and selected system profiles agreed. There had been no
  further reboot; no failed systemd units or automatic restarts of the checked
  SSH, container, orchestration and iSCSI services were recorded.
- The retained current-boot kernel journal contained no selected panic,
  lockup, out-of-memory, GPU/MMU fault, Ethernet watchdog/stall, or storage
  I/O-error/timeout patterns. The known boot-time EQOS memory-controller
  address-decode warning remained.
- Ethernet remained at 1 Gbit/s full duplex, with one carrier-up and zero
  carrier-down events. Approximately 45.3 GB had been received and 85.5 GB
  transmitted under ordinary workloads. OS-reported packet errors and drops,
  and the checked DMA/watchdog/fatal-error counters, were zero. The hardware
  receive-FIFO overflow counter was **1**, versus **0** just after deployment;
  the observation is not an assertion that every hardware counter was zero.
- The existing bounded host CUDA computation and cuBLAS SGEMM checks passed
  again, identifying CUDA driver/runtime API 12090 and the selected cuBLAS
  libraries. This repeat used the default PTX-JIT setting; the separate
  October 16 acceptance checks above explicitly disabled PTX JIT.
- All current running consumer workloads were Ready. The 21 retained pods
  comparable with the October 16 snapshot had unchanged regular-container
  restart counts. One GPU workload pod had instead been replaced at
  02:00 UTC on October 18 and recovered by 02:08 UTC, with zero restarts in
  the new pod and no GPU/OOM/crash errors in its retained logs. Its replacement
  cause was not established. Deleted pods and expired events limit historical
  coverage; readiness alone does not validate a workload image's CUDA upgrade.

An unchanged Linux 6.18.46 comparison board remained healthy after about ten
days of uptime. Its hardware receive-FIFO counter was 533 cumulatively, with
no earlier counter snapshot establishing a delta for this window. It also
recorded two correctable NVMe PCIe link errors, of a class already seen before
the update, without corresponding storage I/O failures. Different traffic
volumes and uptimes prevent treating these counters as a controlled comparison.

This follow-up supports the selected stack on one board under ordinary use.
It does not prove the former rare TX timeout cannot recur or resolve the
separate RX page-pool teardown leak. The following 6.18.46 record is historical
evidence from the earlier two-board baseline.

## Earlier hardware-validated baseline

Linux 6.18.46, OE4T OOT revision `3428d019`, R36.4.4 driver userspace,
CUDA 12.6 targeting `sm_72`, and R35.6.5 GV11B/XUSB firmware form the
headless AGX Xavier baseline. Its archive hash is retained in
[sources.md](sources.md).
Consumers may trim the kernel further and add their own workload contract.

The EQOS configuration is four RX/TX queues, one shared MAC interrupt,
hardware TSO/GSO/GRO enabled, TX ring 1024, TX coalescing 256 microseconds /
5 frames, TX/RX PBL 32/12 with PBLx8, and 36 KiB total RX/TX FIFO depth.
With four active queues, stmmac divides the FIFO into 9 KiB per queue, matching
NVIDIA's Tegra194 nvethernet v5.0 policy. Per-channel interrupts, single-queue
variants and Linux 6.18.51/6.18.52 experiments are outside this baseline.

The baseline also carries the stmmac reset IRQ-window fix. It improves recovery
after a rare TX watchdog but does not claim to prevent the underlying timeout.

## Recorded hardware evidence

The headless stack built and booted on two AGX Xavier systems using consuming
configurations with trimmed kernels. NVMe root, Ethernet, GPU modules/device
nodes, the padded P2972 DTB, host CUDA and basic kernel fan control worked. A
bounded CUDA container test exercised NvMap cgroup charging and reclaim. These
observations do not establish a successful build or hardware test of every
possible standalone kernel configuration.

### Watchdog recovery validation

The reset IRQ-window fix has completed three genuine TX-watchdog recoveries
across two AGX Xavier systems. In all three cases the adapter reset completed,
the link returned within a few seconds, and no interrupt storm, RCU stall,
soft/hard lockup or reboot followed. A separate RX page-pool teardown leak can
remain after recovery and is not fixed by the IRQ-window patch.

### FIFO sizing validation

The 36 KiB RX/TX FIFO policy was first tested as an A/B hardware canary against
the previous 64 KiB-total layout. The vendor-matched 9 KiB-per-queue system
remained free of TX watchdogs past the comparison system's first-failure window,
while the comparison system produced repeated watchdog/reset events. This is
strong hardware evidence for the vendor FIFO layout, but not proof that FIFO
sizing is the sole possible cause of every TX timeout.

### 2026-09-19 pre-FIFO EQOS observation

The earlier four-queue EQOS baseline was observed from **2026-09-19 00:34 UTC
through 2026-09-20 11:50 UTC**, approximately 35 hours under ordinary network traffic.
Read-only checks at the end of that window found:

- the expected queues, shared interrupt, TX ring/coalescing and enabled TSO;
- no failed systemd units, interface RX/TX errors or drops;
- no TX-timeout messages in that boot journal;
- a boot-time EQOS memory-controller address-decode warning, still unclassified.

This record is evidence for that exact observation window and configuration,
not a statement about the current state of any deployed system.

Sustained traffic, thermal stress, broader NvMap limit enforcement and
TensorRT/cuDNN remain unvalidated. Source/configuration checks, compilation,
hardware boot and runtime workload tests are separate evidence. The historical
build and recovery chronology is retained in the
[bring-up archive](archive/bringup-2026-09.md).

## Reproducing the checks

```sh
nix flake check
nix build .#sources --no-link
```

Consumers should run `lib.mkKernelContract { pkgs = ...; kernel = ...; }`
against their final `config.boot.kernelPackages.kernel`, alongside any workload
contract. A cross-generated configuration is useful but does not include every
NixOS module's final kernel changes.

From a consuming flake, evaluate and build its complete system against a local
candidate without changing its lock file. Replace the path and configuration
name with that consumer's values:

```sh
jetson_candidate=/absolute/path/to/jetson-nixos
consumer_configuration=your-configuration
jetpack_r36_candidate=github:anduril/jetpack-nixos/d4c4a515ae57a3c85fa3fb17e02a8fa1fe66a600
nix eval --raw ".#nixosConfigurations.${consumer_configuration}.config.boot.kernelPackages.kernel.version" \
  --override-input jetson-nixos "path:${jetson_candidate}" \
  --override-input jetson-nixos/jetpack-r36 "$jetpack_r36_candidate" --no-write-lock-file
nix build ".#nixosConfigurations.${consumer_configuration}.config.system.build.toplevel" \
  --override-input jetson-nixos "path:${jetson_candidate}" \
  --override-input jetson-nixos/jetpack-r36 "$jetpack_r36_candidate" --no-write-lock-file --no-link
```

Use the consumer's input name if it differs from `jetson-nixos`. Overriding only
the parent can retain an older nested input from the consumer lock. Keep the
explicit child override aligned with this candidate's R36 pin, or update a
scratch consumer lock coherently when changing nested pins. These commands
evaluate or build a closure; activation and boot selection remain separate
steps under the update gates below.

After booting a candidate, compare the runtime EQOS state:

```sh
ethtool -l end0
ethtool -g end0
ethtool -c end0
ethtool -k end0
ethtool -S end0
grep -Ei 'end0|stmmac' /proc/interrupts
journalctl -k -b
```

## cuBLAS computation gate

`cuda-cublas-smoke` is an opt-in native aarch64 package, also available as
`pkgs.jetson-xavier.cuda-cublas-smoke`. It adds no default system dependency.
Build it with the same isolated CUDA scope as the candidate; run it only on
the matching booted system, with an external 30-second timeout:

```sh
cublas_smoke=$(nix build .#cuda-cublas-smoke --no-link --print-out-paths)
cat "$cublas_smoke/share/xavier-cuda-cublas-smoke/dynamic-section.txt"
timeout 30s env CUDA_DISABLE_PTX_JIT=1 \
  "$cublas_smoke/bin/xavier-cuda-cublas-smoke"
```

The package records its final ELF dependencies/RUNPATH. The program records
mapped CUDA driver, runtime and cuBLAS library paths, device capability and
library versions, and requires the loaded runtime to match compiled CUDART.
Its own kernel contains native `sm_72` SASS only; disabling PTX JIT also avoids
silently testing a JIT fallback in a dependency. Explicit device allocations
are three 4 KiB matrices (12 KiB total); driver and cuBLAS internal/context
allocations are additional. It checks all 1024 SGEMM results against 192.

A native-fill success is printed before cuBLAS initialization. Only the final
SGEMM success establishes a passing cuBLAS check; kernel smoke success alone
does not establish library compatibility. `CUBLAS_STATUS_ARCH_MISMATCH`, another
library error, a wrong result or timeout is a failed gate. A passing check
covers this bounded computation, not TensorRT, cuDNN or arbitrary GPU workloads.

## Update gates

1. Check source/patch applicability and the final consumer kernel contract.
2. Build the kernel, DTB, OOT modules, selected userspace/firmware and CUDA smoke
   test, including module ownership/dependency checks and the complete system.
3. Coordinate one device, any dependent workloads, recovery access, a retained
   known-good boot generation, an ESP backup and sufficient free boot-partition
   space.
4. Stage with `nixos-rebuild boot` and perform a coordinated reboot. Never mix
   kernel/OOT/userspace generations using a live switch. Firmware on the tested
   boards does not provide reliable one-shot EFI rollback.
5. Recheck networking, storage, GPU providers, root and video-group CUDA smoke
   tests, container execution, NvMap accounting/release/limits and thermal/fan
   behaviour. Record the exact running closure and duration of sustained tests.

Display, camera and hardware video support are outside the headless scope.
A configuration check is not hardware validation or a claim of complete
platform support.
