<!-- SPDX-License-Identifier: GPL-2.0-only -->
# Baseline and validation records

## Baseline

Linux 6.18.46, OE4T OOT revision `3428d019`, R36.4.4 driver userspace,
CUDA 12.6 targeting `sm_72`, and R35.6.5 GV11B/XUSB firmware form the
headless AGX Xavier baseline. Exact source pins are in [sources.md](sources.md).
Consumers may trim the kernel further and add their own workload contract.

The EQOS configuration is four RX/TX queues, one shared MAC interrupt,
hardware TSO/GSO/GRO enabled, TX ring 1024, TX coalescing 256 microseconds /
5 frames, and TX/RX PBL 32/12 with PBLx8. Per-channel interrupts, single-queue
variants and Linux 6.18.51/6.18.52 experiments are outside this baseline.

The current feature candidate keeps that topology and adds only the March 2026
stmmac reset IRQ-window patch. Its immediate validation target is recovery after
a reproducible TX watchdog: IRQ activity must not storm and the IRQ CPU must not
enter an RCU/soft-lockup. Preventing the original TX timeout is a separate gate.

## Recorded hardware evidence

The headless stack built and booted on two AGX Xavier systems using consuming
configurations with trimmed kernels. NVMe root, Ethernet, GPU modules/device
nodes, the padded P2972 DTB, host CUDA and basic kernel fan control worked. A
bounded CUDA container test exercised NvMap cgroup charging and reclaim. These
observations do not establish a successful build or hardware test of every
possible standalone kernel configuration.

### 2026-09-19 EQOS observation

The four-queue EQOS baseline was observed from **2026-09-19 00:34 UTC through
2026-09-20 11:50 UTC**, approximately 35 hours under ordinary network traffic.
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
