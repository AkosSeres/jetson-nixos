<!-- SPDX-License-Identifier: GPL-2.0-only -->
# Source provenance

## Git inputs

`flake.nix` names immutable revisions; `flake.lock` records the fetched content
hashes. The NVIDIA Git input additionally requests recursive submodules.

| Input | Revision | Intended role |
| --- | --- | --- |
| [nixpkgs](https://github.com/NixOS/nixpkgs/commit/f4f698677b11021a8f84f452e23ae9ef2427bec3) | `f4f698677b11021a8f84f452e23ae9ef2427bec3` | Audited NixOS 26.05 package set |
| [nvidia-oot](https://github.com/OE4T/nvidia-kernel-oot/commit/3428d01926de97ca8b0f25fe6edd9c76e19472a1) | `3428d01926de97ca8b0f25fe6edd9c76e19472a1` | OE4T R36.5 / Linux 6.18 OOT superproject |
| [jetpack-r36](https://github.com/anduril/jetpack-nixos/commit/d4c4a515ae57a3c85fa3fb17e02a8fa1fe66a600) | `d4c4a515ae57a3c85fa3fb17e02a8fa1fe66a600` | JetPack 6.2.3 / L4T 36.5.2 package recipes |
| [jetpack-r35](https://github.com/anduril/jetpack-nixos/commit/cade3c198b8169ee7fd46dbdc283c714d9923951) | `cade3c198b8169ee7fd46dbdc283c714d9923951` | JetPack 5.1.7 / L4T 35.6.5 firmware recipes |

Both JetPack inputs are fetched as source-only inputs, not imported flakes.
The experimental overlay imports R36's package-scope recipes explicitly.
The R36 pin records the BSP's native CUDA 12.6.10 and driver 540.5.0. This
packaging metadata is independent of the selected CUDA 12.9 application toolkit
and compatibility UMD described below. The R35 pin also contains newer
generations that must not become the userspace source by accident.

The Armbian installer tracks APT candidates from common/t234 R36.4 plus t194
R35.6 repositories. It is architectural evidence, **not** a byte-exact userspace
manifest. Choosing L4T 36.4.4 made the earlier input reproducible; it did not establish
that the original demonstration used those exact packages or prove Xavier
runtime compatibility. The selected L4T 36.5.2 userspace is a subsequent
candidate with its own build and runtime validation gates.

## CUDA toolkit, compatibility UMD and cuBLAS

The private `cudaPackages_12_9` scope uses the pinned nixpkgs copy of NVIDIA's
[CUDA 12.9 Update 1 redistributable manifest](https://developer.download.nvidia.com/compute/cuda/redist/redistrib_12.9.1.json),
with the complete Jetson cuBLAS component pinned independently:

| Component | Version | NVIDIA payload |
| --- | --- | --- |
| nvcc | 12.9.86 | `linux-aarch64` Jetson |
| cudart | 12.9.79 | `linux-aarch64` Jetson |
| CCCL | 12.9.27 | `linux-aarch64` Jetson |
| `cuda_compat` | 12.9.40580548 | `linux-aarch64` Jetson |
| cuBLAS and cuBLASLt | 12.2.5.6 | `linux-aarch64` Jetson |

[`sources/cublas-12.2.5.6.json`](../sources/cublas-12.2.5.6.json) preserves the
complete original cuBLAS entry from NVIDIA's
[CUDA 12.2 Update 2 manifest](https://developer.download.nvidia.com/compute/cuda/redist/redistrib_12.2.2.json).
The private per-library override passes that release entry to `buildRedist`
at construction time, retaining its original version, URLs and hashes.
It packages matching cuBLAS headers, `libcublas`, `libcublasLt` and other
component outputs with the same CUDA 12.9 hooks and declared dependency scope.
It does not switch the whole toolkit or bring another scope's runtime/UMD.
A consumer's nixpkgs follow can change the other components and package recipes;
inspect the final source selection and closure too.

The selected payload is
[`libcublas-linux-aarch64-12.2.5.6-archive.tar.xz`](https://developer.download.nvidia.com/compute/cuda/redist/libcublas/linux-aarch64/libcublas-linux-aarch64-12.2.5.6-archive.tar.xz),
SHA-256 `db001ba7f3e33568846b1c37ccdf54dcea66396975e43720471d799d08e1eb5f`.
NVIDIA cuobjdump inspection finds native `sm_72` cubins in both shared libraries;
their embedded PTX targets `sm_90`, so the Xavier gate must exercise native code.
NVIDIA documents [same-major toolkit/library mixing](https://docs.nvidia.com/deploy/cuda-compatibility/minor-version-compatibility.html),
subject to library dependencies and available APIs. This supports testing the
mixed component selection; it does not validate all CUDA 12.9 library APIs or
the custom Xavier/mainline stack.

The original Jetson cuBLAS 12.6.4.1 payload contains only `sm_87` code; its
12.9.1.4 successor contains only `sm_87` and `sm_101` cubins. Neither includes
Volta code. Their isolated Xavier tests fail `cublasCreate` with
`CUBLAS_STATUS_ARCH_MISMATCH`, including the CUDA 12.6 baseline. A tested SBSA
12.9 alternative also failed initialization and was not selected. See
[validation](validation.md) for the trial matrix and scope of those failures.

The selected compatibility payload is
[`cuda_compat-linux-aarch64-12.9.40580548-archive.tar.xz`](https://developer.download.nvidia.com/compute/cuda/redist/cuda_compat/linux-aarch64/cuda_compat-linux-aarch64-12.9.40580548-archive.tar.xz),
SHA-256 `c03fe18b9d23881f068ac97b45001a47778f83d2361728427a3f92b551b1c898`.
Its Jetson `libcuda.so.1.1` depends on `libnvrm_gpu.so` and `libnvrm_mem.so`;
the Jetson packaging extension supplies the matching R36.5.2 core libraries.
Nixpkgs propagates this compatibility UMD and prepends it to CUDA application
and library RUNPATHs. Keeping the original R36.5.2 driver package derivations
does not keep the native BSP UMD selected inside those application processes.

NVIDIA's [CUDA for Tegra upgrade table](https://docs.nvidia.com/cuda/archive/12.9.2/cuda-for-tegra-appnote/index.html#deployment-considerations-for-cuda-upgrade-package)
documents CUDA 12.9 upgrade packages for JetPack 6.x. Record actual mapped
libraries and driver API versions during hardware testing. `mk-overlay` retains
CUDA 12.6.10 as native BSP metadata and its packaging-helper selector while the
exported application package scope selects CUDA 12.9. Other math libraries and
inference stacks need their own dependency and GPU-architecture assessment;
cuBLAS selection alone does not establish their compatibility.

## Linux archive

The selected maintenance release is `6.18.57`, recorded in
[`sources/linux.nix`](../sources/linux.nix).

- [Release archive](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.57.tar.xz)
- [Publisher checksum list](https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc)
- SHA-256: `5bd9acdc82ec5efc3790ae840e5aaa40dfde7efff261cf6dde902dc570acf98c`
- Nix SRI: `sha256-W9ms3ILsXvw3kK6EDlqqQN/efv/yYc9t3pAtxXCs+Yw=`

Linux `6.18.46` is the earlier two-board hardware baseline (archive SHA-256
`f5d44b93808b02cc2969c5404ba081d97523719c9fd2ba2de6db318b4141cca0`).
The [validation record](validation.md) separates that historical evidence from
the staged 6.18.57 checks and approximately 68-hour follow-up on one updated
board, and describes the upstream stmmac maintenance fixes.

This is an explicit reproducibility pin, not an automatic update mechanism. The
community reference used `6.18.22` (archive SHA-256
`a23c92faf3657385c2c6b5f4edd8f81b808907ebe603fa30699eae224da55f59`).
The reference patches and generated configuration were checked on that baseline
before moving to 6.18.46. The 6.18.51/6.18.52 experiments do not form part of
the hardware-validated baseline.

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
inventory. Paths are relative to this repository; the kernel/OOT derivations
apply the vendored files under `patches/armbian/`. Their original revision,
paths and licenses are recorded in the [provenance note](../patches/armbian/README.md).
The ordered selection is unchanged from the former Armbian input. Patch bytes
are unchanged except for Linux patch `0011`, rebased for 6.18.57 as described
below and in the provenance note.

### Linux: nine patches, 0004–0012

Original source directory (local copies: `patches/armbian/linux/`):
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

Linux patch `0011` retains the original authors' RX recovery code, attribution,
upstream link, `Fixes` tag and sign-offs. Its local 6.18.57 refresh adds a rebase
note, updates hunk positions and includes the existing `fcs_stripped` declaration
in the context. This is a patch-byte exception to the original import, not a
change to the recovery logic.

### OOT: fifteen patches, 0006–0020

Original source directory (local copies: `patches/armbian/nvidia-oot/`):
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
- `patches/linux/0006-*` carries the March 2026 netdev patch that frees stmmac
  IRQs before setting `STMMAC_DOWN` during watchdog reset and avoids freeing
  them a second time in `__stmmac_release()`. Hardware validation across three
  genuine watchdog recoveries on two AGX Xavier systems showed link recovery
  without the prior interrupt-storm / RCU / soft-lockup cascade.
- `patches/linux/0007-*` sets Tegra194 EQOS RX/TX FIFO depth to 36 KiB total.
  With the validated four-queue topology, stmmac divides this into 9 KiB per
  queue, matching NVIDIA's nvethernet v5.0 FIFO policy instead of mainline's
  hardware-reported 64 KiB total / 16 KiB-per-queue layout.

Local OOT patches run after the fifteen reference patches:

- `patches/nvidia-oot/0001-*` omits the hypervisor-only BPMP module and preserves
  the external host1x firewall when the in-tree host1x config is disabled.
- `patches/nvidia-oot/0002-*` excludes optional camera, audio, SPI, VSE/SE and CEC
  providers from the headless OOT build, avoiding overlaps with mainline modules.
- `patches/nvidia-oot/0003-*` detects the context-bearing `struct syscore` API
  introduced to Linux 6.18.y by commit `ff422b8597c2` in 6.18.52. It preserves
  the watchdog's static registration lifetime and existing singleton
  suspend/resume behaviour through correctly typed callback adapters, while
  retaining the legacy API on older kernels. Probe-error and remove paths
  unregister the same object; this does not disable the watchdog or fix its
  pre-existing singleton/multiple-device assumptions. See the
  [upstream API change](https://github.com/gregkh/linux/commit/ff422b8597c287dbbac1d444330770114131dfba).
- `patches/nvgpu/0001-*` fixes matching-free and partial scatterlist cleanup in
  the pinned nvgpu tree, retaining the original author's attribution.
- `patches/nvgpu/0002-*` resets the usermode-mapping retry error each pass so
  removal of the final control entry after contention cannot leave runtime PM
  spinning on a stale `-EBUSY`. The `nvgpu-usermode-retry` flake check compiles
  the actual extracted function and upstream list helpers with host-only mocks;
  this does not establish hardware recovery or any incident's exact execution path.

### NVIDIA R36.5.2 security backports

After the existing nineteen OOT patches, apply three NvMap and eight nvgpu
patches from [the upstream patch manifest](../patches/nvidia-r36.5.2/manifest.json).
The exact NVIDIA email patches are retained byte-for-byte, with original
authors, review/sign-off metadata and licenses. Apply them within their source
subdirectories; the source pins and modern-kernel adaptations remain unchanged.

The NvMap series fixes invalid-handle dereferences and kernel out-of-bounds
access through unchecked fd-from-list offset/size/range calculations. The
nvgpu series adds checked arithmetic and range validation in GV11B, AS
allocation/remapping, copy-engine and register-access paths. Its helper
dependencies require applying all eight patches together before building.
See the [provenance and integration note](../patches/nvidia-r36.5.2/README.md).

These patches preserve the existing nvgpu DMA failure cleanup and NvMap page
allocation/accounting/retry policy. They require a fresh matching module build
and hardware regression checks; source applicability alone is not runtime
validation or a complete security audit.

### Allocator behaviour in the pinned sources

Linux 6.18 already has the memcg page representation required for accounted
userspace mappings. The pinned OOT NvMap uses `__GFP_ACCOUNT`, so no accounting
backport is applied. A bounded CUDA container test subsequently demonstrated
cgroup charging and reclaim; broader limit and stress testing remains incomplete.

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
zero free capacity. Padding preserves its tree contents. Subsequent successful
hardware boots are recorded separately in [validation.md](validation.md);
the precise firmware failure mechanism remains inferred from source evidence.

## Updating pins

Change only the intended revision in `flake.nix`, then run
`nix flake update <input-name>` and inspect the lock-file diff. For Linux, update
the version, URL, and publisher-checked archive hash together. Re-audit the
submodule table, patch inventory, userspace generation, licensing, and integration
constraints as applicable. Run the source checks and builds again.

An input whose original URL contains an exact commit does not advance merely by
running a generic flake update. Do not silently replace this stack with a branch
tip or newer JetPack default.
