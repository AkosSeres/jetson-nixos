<!-- SPDX-License-Identifier: MIT -->
# Licensing boundaries

The root [MIT license](../LICENSE) covers original project code and documentation.
It does not replace licenses on fetched upstream work, patches, or future binary
dependencies. SPDX headers on the patch inventory describe our metadata file,
not the patch bodies it references.

## Upstream components

| Component | Evidence and boundary |
| --- | --- |
| Linux | GPL-2.0-only as a whole, with per-file licenses and the UAPI syscall exception where applicable; follow the [kernel licensing rules](https://www.kernel.org/doc/html/latest/process/license-rules.html) and source headers |
| Armbian reference | The pinned build repository contains a [GPLv2 LICENSE](https://github.com/CybrixSystems/armbian-build/blob/b673d05018528b6735408bd777f4e3bf33d5becf/LICENSE); individual carried patches also require their own provenance and target-file review |
| JetPack NixOS recipes | [MIT](https://github.com/anduril/jetpack-nixos/blob/98a83b7d737ed636439c7fdc628a875eaf4cce15/LICENSE); this describes packaging code, not NVIDIA payloads |
| NVIDIA OOT / nvgpu | Mixed per-file licensing. The audited [NvMap allocator](https://github.com/OE4T/linux-nv-oot/blob/ccf7646c57462776fe1093af6643c54653f59861/drivers/video/tegra/nvmap/nvmap_alloc.c) and [nvgpu Linux DMA code](https://github.com/OE4T/linux-nvgpu/blob/d530a48d64f9ad3020d9f3307f53e8dde8e3fba1/drivers/gpu/nvgpu/os/linux/linux-dma.c) identify GPL-2.0-only |
| NVIDIA nvdisplay | Its [COPYING](https://github.com/OE4T/nv-kernel-display-driver/blob/f48baa7a63e596a239e18be2dfae300aaf74d55b/COPYING) describes MIT files except where otherwise noted and MIT/GPLv2 for the linked kernel module; preserve all applicable notices |
| CUDA, L4T userspace, firmware | Separate NVIDIA terms. No project MIT or recipe license grants rights over those binaries |

The OE4T superproject has no root LICENSE/COPYING file at the pinned revision.
Its submodules' licenses are not a blanket license for copying the superproject's
own scripts. This scaffold fetches the original tree; it does not vendor its
build scripts. Review applicable terms before copying or adapting them.

## Rules for later imports and distribution

- Preserve original patch authorship, commit metadata, SPDX headers, and notices.
- Record the exact source revision and target tree of every carried patch.
- Treat a patch containing upstream code as upstream-derived work, not
  automatically as an original MIT contribution.
- Add required license texts/notices when vendoring code; do not put a blanket
  MIT label on a vendor patch directory.
- Keep CUDA, firmware, BSP archives, and extracted proprietary binaries out of
  Git. Verify their actual download and redistribution terms before publishing
  packages, images, containers, or binary-cache artifacts.
- A private repository does not eliminate obligations attached to distribution.

This is a record of licensing boundaries, not a complete redistribution audit.
No blanket permission to publish the eventual combined image is claimed.
