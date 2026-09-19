<!-- SPDX-License-Identifier: MIT -->
# Source provenance

## Git inputs

`flake.nix` names immutable revisions; `flake.lock` records the fetched content
hashes. The NVIDIA Git input additionally requests recursive submodules.

| Input | Revision | Intended role |
| --- | --- | --- |
| [nixpkgs](https://github.com/NixOS/nixpkgs/commit/f4f698677b11021a8f84f452e23ae9ef2427bec3) | `f4f698677b11021a8f84f452e23ae9ef2427bec3` | Audited NixOS 26.05 package set |
| [armbian](https://github.com/CybrixSystems/armbian-build/commit/b673d05018528b6735408bd777f4e3bf33d5becf) | `b673d05018528b6735408bd777f4e3bf33d5becf` | CybrixSystems' Xavier patch and board reference |
| [nvidia-oot](https://github.com/OE4T/nvidia-kernel-oot/commit/3428d01926de97ca8b0f25fe6edd9c76e19472a1) | `3428d01926de97ca8b0f25fe6edd9c76e19472a1` | OE4T R36.5 / Linux 6.18 OOT superproject |
| [jetpack-r36](https://github.com/anduril/jetpack-nixos/commit/98a83b7d737ed636439c7fdc628a875eaf4cce15) | `98a83b7d737ed636439c7fdc628a875eaf4cce15` | JetPack 6.2.1 / L4T 36.4.4 package recipes |
| [jetpack-r35](https://github.com/anduril/jetpack-nixos/commit/cade3c198b8169ee7fd46dbdc283c714d9923951) | `cade3c198b8169ee7fd46dbdc283c714d9923951` | JetPack 5.1.7 / L4T 35.6.5 firmware recipes |

Both JetPack inputs are fetched as source-only inputs, not imported flakes.
The experimental overlay imports R36's package-scope recipes explicitly.
The R36 pin records CUDA 12.6.10 and driver 540.4.0; the R35 pin also contains
newer generations that must not become the userspace source by accident.

The Armbian installer tracks APT candidates from common/t234 R36.4 plus t194
R35.6 repositories. It is architectural evidence, **not** a byte-exact userspace
manifest. Choosing L4T 36.4.4 makes our input reproducible; it does not establish
that the original demonstration used those exact packages or prove Xavier
runtime compatibility.

## Linux archive

The known-good version is `6.18.46`, recorded in
[`sources/linux.nix`](../sources/linux.nix).

- [Release archive](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.46.tar.xz)
- [Publisher checksum list](https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc)
- SHA-256: `f5d44b93808b02cc2969c5404ba081d97523719c9fd2ba2de6db318b4141cca0`
- Nix SRI: `sha256-9dRLk4CLAswpacVAS6CB2XUjcZyf0rot5tsxi0FBzKA=`

This is an explicit reproducibility pin, not an automatic update mechanism. The
community reference used `6.18.22` (archive SHA-256
`a23c92faf3657385c2c6b5f4edd8f81b808907ebe603fa30699eae224da55f59`).
The reference patches and generated configuration were checked on that baseline
before moving to 6.18.46. Later 6.18.51/6.18.52 experiments are not part of this
known-good baseline.

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
inventory. Every path is relative to the locked Armbian source; the kernel/OOT
derivations apply these directly from that input. The inventory records the audited reference
series, not a guarantee that every patch remains necessary after version changes.

### Linux: nine patches, 0004–0012

Source directory:
[`patch/kernel/archive/uefi-arm64-6.18`](https://github.com/CybrixSystems/armbian-build/tree/b673d05018528b6735408bd777f4e3bf33d5becf/patch/kernel/archive/uefi-arm64-6.18).
These target the Linux tree.

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

### Local patches

Local Linux patches run after the nine reference patches:

- `patches/linux/0001-*` removes the initial defconfig Tegra DRM selection so
  Nix's config generator can disable the mainline host1x provider.
- `patches/linux/0002-*` adds CPU/GPU active fan trips at 45/60/75 C with 4 C
  hysteresis, while preserving all critical shutdown temperatures.
- `patches/linux/0003-*` makes the built-in host1x context bus independently
  selectable, retaining IOMMU integration without the in-tree host1x driver.
- `patches/linux/0004-*` sets Tegra194 stmmac's default TX ring to 1024
  descriptors and TX completion cadence to 256 microseconds / 5 frames, matching
  the validated NVIDIA nvethernet policy while retaining the shared-IRQ topology.
- `patches/linux/0005-*` sets Tegra194 EQOS PBL to TX 32 and RX 12 with PBLx8,
  matching the validated nvethernet DMA policy.

Local OOT patches run after the fifteen reference patches:

- `patches/nvidia-oot/0001-*` omits the hypervisor-only BPMP module and preserves
  the external host1x firewall when the in-tree host1x config is disabled.
- `patches/nvidia-oot/0002-*` excludes optional camera, audio, SPI, VSE/SE and CEC
  providers from the headless OOT build, avoiding overlaps with mainline modules.
- `patches/nvgpu/0001-*` fixes matching-free and partial scatterlist cleanup in
  the pinned nvgpu tree, retaining the original author's attribution.

### Allocator behaviour in the pinned sources

Linux 6.18 already has the memcg page representation required for accounted
userspace mappings. The pinned OOT NvMap uses `__GFP_ACCOUNT`, so no accounting
backport is applied. A CUDA-backed ML workload subsequently demonstrated cgroup
charging and reclaim; broader limit and stress testing remains incomplete.

NvMap page coloring is disabled in this reference configuration. The active
noncolored allocator already retries failed allocations. The colored allocator
still lacks that retry: review its four-argument allocation helper and failure
cleanup before intentionally enabling coloring. The pinned nvgpu page-directory
allocation flow already assigns its memory pointer only after successful
allocation, so an additional legacy null-guard patch is unnecessary.

The retained nvgpu fix belongs at
`nvgpu/drivers/gpu/nvgpu/os/linux/linux-dma.c` in the superproject. The NvMap
patches belong under `nvidia-oot/drivers/video/tegra/nvmap/`. No diagnostic kernel
patches are carried.

## UEFI DTB padding

`pkgs/uefi-dtb.nix` uses the locked device-tree compiler to reserve 64 KiB in the
final selected DTB. No additional source pin or firmware patch is introduced.

- [systemd-boot 260.2 DTB installation](https://github.com/systemd/systemd/blob/v260.2/src/boot/devicetree.c)
  allocates from the file size, optionally invokes the DT fixup protocol, then
  installs the configuration table. Allocation alone does not enlarge the FDT
  header's declared size.
- NVIDIA's [UEFI DTB loader](https://github.com/NVIDIA/edk2-nvidia/blob/2be5d5da5df85a0c4637f4e6d41340db746dd735/Silicon/NVIDIA/Library/DxeDtPlatformDtbLoaderLib/DxeDtPlatformDtbKernelLoaderLib.c)
  applies firmware-media overlays when a replacement FDT is installed. Its own
  default-DTB allocation reserves extra space; the notification path does not
  similarly expand a bootloader-supplied tree. This source is from the older
  firmware family, not a verified exact match for the tested firmware binary.
- A [first-hand Jetson report](https://forums.developer.nvidia.com/t/the-system-fails-to-boot-with-a-custom-dtb-with-jetpack-5-1-4-6-2/338578/10)
  traces the same invalid-header message to overlay space exhaustion and reports
  successful boot after adding padding. That Orin result is supporting evidence,
  not proof that the Xavier trial failed for the identical reason.

The original staged P2972 DTB was valid and byte-identical to its build output,
but its 128,354-byte declared size ended exactly at the end of its strings block:
zero free capacity. The padding candidate preserves its tree contents. Neither
offline checks nor the source evidence establish successful hardware boot.

## Updating pins

Change only the intended revision in `flake.nix`, then run
`nix flake update <input-name>` and inspect the lock-file diff. For Linux, update
the version, URL, and publisher-checked archive hash together. Re-audit the
submodule table, patch inventory, userspace generation, licensing, and integration
constraints as applicable. Run the source checks and builds again.

An input whose original URL contains an exact commit does not advance merely by
running a generic flake update. Do not silently replace this stack with a branch
tip or newer JetPack default.
