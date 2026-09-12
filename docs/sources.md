<!-- SPDX-License-Identifier: MIT -->
# Source provenance

## Git inputs

`flake.nix` names immutable revisions; `flake.lock` records the fetched content
hashes. The NVIDIA Git input additionally requests recursive submodules.

| Input | Revision | Intended role |
| --- | --- | --- |
| [nixpkgs](https://github.com/NixOS/nixpkgs/commit/f4f698677b11021a8f84f452e23ae9ef2427bec3) | `f4f698677b11021a8f84f452e23ae9ef2427bec3` | Audited infra NixOS 26.05 homelab package set |
| [armbian](https://github.com/CybrixSystems/armbian-build/commit/b673d05018528b6735408bd777f4e3bf33d5becf) | `b673d05018528b6735408bd777f4e3bf33d5becf` | CybrixSystems' Xavier patch and board reference |
| [nvidia-oot](https://github.com/OE4T/nvidia-kernel-oot/commit/3428d01926de97ca8b0f25fe6edd9c76e19472a1) | `3428d01926de97ca8b0f25fe6edd9c76e19472a1` | OE4T R36.5 / Linux 6.18 OOT superproject |
| [jetpack-r36](https://github.com/anduril/jetpack-nixos/commit/98a83b7d737ed636439c7fdc628a875eaf4cce15) | `98a83b7d737ed636439c7fdc628a875eaf4cce15` | JetPack 6.2.1 / L4T 36.4.4 package recipes |
| [jetpack-r35](https://github.com/anduril/jetpack-nixos/commit/cade3c198b8169ee7fd46dbdc283c714d9923951) | `cade3c198b8169ee7fd46dbdc283c714d9923951` | JetPack 5.1.7 / L4T 35.6.5 firmware recipes |

Both JetPack inputs are source-only, not imported flakes or active overlays.
The R36 pin records CUDA 12.6.10 and driver 540.4.0; the R35 pin also contains
newer generations that must not become the userspace source by accident.

The Armbian installer tracks APT candidates from common/t234 R36.4 plus t194
R35.6 repositories. It is architectural evidence, **not** a byte-exact userspace
manifest. Choosing L4T 36.4.4 makes our input reproducible; it does not establish
that the original demonstration used those exact packages or prove Xavier
runtime compatibility.

## Linux archive

The reproduction version is `6.18.22`, recorded in
[`sources/linux.nix`](../sources/linux.nix).

- [Release archive](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.22.tar.xz)
- [Publisher checksum list](https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc)
- SHA-256: `a23c92faf3657385c2c6b5f4edd8f81b808907ebe603fa30699eae224da55f59`
- Nix SRI: `sha256-ojyS+vNlc4XCxrX07dj4G4CJB+vmA/owaZ6uIk2lX1k=`

This is a hash of the compressed archive, not a recursive NAR hash.
Fetching verifies the bytes against the recorded hash; it does not perform
detached-signature verification or certify the release's security suitability.

## NVIDIA submodules

The exact gitlinks are recorded by the superproject revision above. Its
[`.gitmodules`](https://github.com/OE4T/nvidia-kernel-oot/blob/3428d01926de97ca8b0f25fe6edd9c76e19472a1/.gitmodules)
also names mutable branches: those are not our source of truth.

| Path | OE4T repository | Gitlink revision |
| --- | --- | --- |
| `hardware/nvidia/t23x/nv-public` | `t23x-public-dts` | `ed1b0f6b113bb050c8cda1ccb411a163f8e2799f` |
| `hardware/nvidia/tegra/nv-public` | `tegra-public-dts` | `8ba5d53ef1e1753f9f2a5b1f7b7b5fc5039de68e` |
| `hwpm` | `linux-hwpm` | `4d8a6998760d85f98637dbf61597bfbb88158206` |
| `kernel-devicetree` | `kernel-devicetree` | `19952c8e25702e9de23500c3b1fb351bf4380446` |
| `nvdisplay` | `nv-kernel-display-driver` | `f48baa7a63e596a239e18be2dfae300aaf74d55b` |
| `nvethernetrm` | `nvethernetrm` | `22e582e01d1c9c258ac56873f1aa0822acb695f3` |
| `nvgpu` | `linux-nvgpu` | `d530a48d64f9ad3020d9f3307f53e8dde8e3fba1` |
| `nvidia-oot` | `linux-nv-oot` | `ccf7646c57462776fe1093af6643c54653f59861` |

The recursive input hash covers the fetched contents. The scaffold check also
rejects missing/empty submodule directories. No submodules are added to this
repository itself.

## Reference patch inventories

[`sources/patches.nix`](../sources/patches.nix) is the ordered, machine-readable
inventory. Every path is relative to the locked Armbian source; no patch body is
copied or applied by this scaffold. The inventory records the audited reference
series, not a guarantee that every patch remains necessary after version changes.

### Linux: nine patches, 0004–0012

Source directory:
[`patch/kernel/archive/uefi-arm64-6.18`](https://github.com/CybrixSystems/armbian-build/tree/b673d05018528b6735408bd777f4e3bf33d5becf/patch/kernel/archive/uefi-arm64-6.18).
These will target the Linux tree.

| Patch | Purpose |
| --- | --- |
| 0004 | T194 NvMap/carveout device-tree node |
| 0005 | Minimal NVRM device-tree node; its filename does not imply full display support |
| 0006 | Thermal-zone names used by the vendor userspace |
| 0007 | Junction-temperature thermal zone |
| 0008 | EQOS AXI outstanding-request limits |
| 0009 | EMC clock floor from interconnect requests |
| 0010 | EQOS interconnect bandwidth requests |
| 0011 | RX buffer-exhaustion recovery |
| 0012 | EQOS multi-queue device-tree configuration |

The unrelated HiKey960 and Phytium patches in the same directory are excluded.

### OOT: fifteen patches, 0006–0020

Source directory:
[`extensions/jetson-l4t/files/dkms`](https://github.com/CybrixSystems/armbian-build/tree/b673d05018528b6735408bd777f4e3bf33d5becf/extensions/jetson-l4t/files/dkms).
Paths target the superproject root, including `nvidia-oot/` and `nvdisplay/`,
not Linux's old vendor-tree `nvidia/` directory.

| Patches | Purpose |
| --- | --- |
| 0006 | T194 memory-controller helper support |
| 0007–0015 | T194 identification/HAL registration and an NVRM-only probe path |
| 0016 | T194 host1x-fence module alias |
| 0017 | Non-fatal CAN clock-parent selection |
| 0018 | Conftest for three- versus four-argument `pci_resize_resource` |
| 0019 | Require `crypto_akcipher_verify` before selecting LKCA |
| 0020 | fbdev compatibility with preallocated `fb_info` |

The audit found 0018 inert on 6.18.22 and needed on 6.18.46, and 0020 selecting
different compatible paths on those releases. Patch 0019 protects both against
an unavailable crypto API. Keep the conditional adaptations in the reproduction
inventory; validate applicability again when implementing or updating.

### Existing infra patches: migration decisions, not imported patches

Audit reference:
[`akos/infra@0dbe1e87a0b998c4f10efafb53649ab5f4cc9606`](https://git.akos.cc/akos/infra/src/commit/0dbe1e87a0b998c4f10efafb53649ab5f4cc9606).
These decisions apply to this experimental port only; they do not remove patches
from the production 5.10 configuration.

| Existing patch | Decision for the reference build |
| --- | --- |
| `linux-memcg-data-kmem.patch` | Omit: the 6.18 kernel already has the relevant representation |
| `tegra194-nvmap-account-backing-pages.patch` | Omit: the pinned OOT NvMap already uses `__GFP_ACCOUNT`; runtime accounting still needs testing |
| `tegra194-nvmap-retry-colored-allocations.patch` | Omit while reference OOT coloring is disabled; the active noncolored allocator already retries |
| `tegra194-nvgpu-fix-no-iommu-alloc-failure-unwind.patch` | Port in the OOT implementation step; the matching-free and partial-SG cleanup gaps remain |
| `tegra194-nvgpu-pd-alloc-null-guards.patch` | Omit: the pinned allocation flow makes the old guard patch obsolete |

The colored allocator itself still lacks the retry. If coloring is intentionally
re-enabled, adapt that patch to the OOT NvMap source and its four-argument helper
before enabling it. This is not an upstream-fix claim.

The retained nvgpu fix belongs at
`nvgpu/drivers/gpu/nvgpu/os/linux/linux-dma.c` in the superproject. The NvMap
patches belong under `nvidia-oot/drivers/video/tegra/nvmap/`. No diagnostic kernel
patches are planned.

## Updating pins

Change only the intended revision in `flake.nix`, then run
`nix flake update <input-name>` and inspect the lock-file diff. For Linux, update
the version, URL, and publisher-checked archive hash together. Re-audit the
submodule table, patch inventory, userspace generation, licensing, and integration
constraints as applicable. Run the source checks and builds again.

An input whose original URL contains an exact commit does not advance merely by
running a generic flake update. Do not silently replace this stack with a branch
tip or newer JetPack default.
