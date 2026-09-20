<!-- SPDX-License-Identifier: MIT -->
# Current baseline and validation

## Baseline

Linux 6.18.46, OE4T OOT revision `3428d019`, R36.4.4 driver userspace,
CUDA 12.6 targeting `sm_72`, and R35.6.5 GV11B/XUSB firmware form the
headless AGX Xavier baseline. Exact source pins are in [sources.md](sources.md).
Consumers may trim the kernel further and add their own workload contract.

The EQOS configuration is four RX/TX queues, one shared MAC interrupt,
hardware TSO/GSO/GRO enabled, TX ring 1024, TX coalescing 256 microseconds /
5 frames, and TX/RX PBL 32/12 with PBLx8. Per-channel interrupts, single-queue
variants and Linux 6.18.51/6.18.52 experiments are outside this baseline.

## Recorded hardware evidence

The headless stack built and booted on two AGX Xavier systems using a consuming
configuration's trimmed kernel. NVMe root, Ethernet, GPU modules/device nodes,
the padded P2972 DTB, host CUDA and basic kernel fan control worked. A CUDA-backed
ML container exercised NvMap cgroup charging and reclaim. These observations
do not establish a successful build or hardware test of the broader standalone
kernel configuration.

The current EQOS baseline was observed on one canary from **2026-09-19
00:34 UTC through 2026-09-20 11:50 UTC**, approximately 35 hours under ordinary
cluster traffic. Read-only checks at the end of that window found:

- the expected queues, shared interrupt, TX ring/coalescing and enabled TSO;
- no failed systemd units, interface RX/TX errors or drops;
- no TX-timeout messages in the current boot journal;
- a boot-time EQOS memory-controller address-decode warning, still unclassified.

The other system remained on an older configuration with TSO disabled. Its
longer uptime is not evidence for the current EQOS baseline; historical TX
timeouts and ongoing page-pool shutdown warnings belong to that older image.
Host identities and deployment records belong in the consuming repository.

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

## Update gates

1. Check source/patch applicability and the final consumer kernel contract.
2. Build the kernel, DTB, OOT modules, selected userspace/firmware and CUDA smoke
   test, including module ownership/dependency checks and the complete system.
3. Coordinate one node, its workloads, recovery access, a retained known-good
   boot generation, an ESP backup and sufficient free boot-partition space.
4. Stage with `nixos-rebuild boot` and perform a coordinated reboot. Never mix
   kernel/OOT/userspace generations using a live switch. Firmware on the tested
   boards does not provide reliable one-shot EFI rollback.
5. Recheck networking, storage, GPU providers, root and video-group CUDA smoke
   tests, container execution, NvMap accounting/release/limits and thermal/fan
   behaviour. Record the exact running closure and duration of sustained tests.

llama.cpp remains an optional consumer workload. Display, camera and hardware
video support are outside the headless scope. A configuration check is not a
hardware validation or a claim of complete platform support.
