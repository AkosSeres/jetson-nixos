<!-- SPDX-License-Identifier: GPL-2.0-only -->
# Licensing boundaries

The root [GPL-2.0-only license](../LICENSE) covers original Nix code and documentation.
The CUDA smoke-test program retains its [MIT license](../tests/LICENSE).
The project license does not replace licenses on fetched upstream work, patches,
or future binary dependencies. SPDX headers on the patch inventory describe our metadata file,
not the patch bodies it references.

## Upstream components

| Component | Evidence and boundary |
| --- | --- |
| Linux | GPL-2.0-only as a whole, with per-file licenses and the UAPI syscall exception where applicable; follow the [kernel licensing rules](https://www.kernel.org/doc/html/latest/process/license-rules.html) and source headers |
| Vendored Armbian patches | Original headers and sign-offs are retained under `patches/armbian/`, alongside the upstream [GPLv2 license](../patches/armbian/LICENSE), target-source [notices](../patches/armbian/NOTICE), nvdisplay [COPYING](../patches/armbian/nvidia-oot/COPYING), and [provenance](../patches/armbian/README.md); their upstream terms are retained |
| JetPack NixOS recipes | [MIT](https://github.com/anduril/jetpack-nixos/blob/98a83b7d737ed636439c7fdc628a875eaf4cce15/LICENSE); this describes packaging code, not NVIDIA payloads |
| NVIDIA OOT / nvgpu | Mixed per-file licensing. The audited [NvMap allocator](https://github.com/OE4T/linux-nv-oot/blob/ccf7646c57462776fe1093af6643c54653f59861/drivers/video/tegra/nvmap/nvmap_alloc.c) and [nvgpu Linux DMA code](https://github.com/OE4T/linux-nvgpu/blob/d530a48d64f9ad3020d9f3307f53e8dde8e3fba1/drivers/gpu/nvgpu/os/linux/linux-dma.c) identify GPL-2.0-only |
| NVIDIA nvdisplay | Its [COPYING](https://github.com/OE4T/nv-kernel-display-driver/blob/f48baa7a63e596a239e18be2dfae300aaf74d55b/COPYING) describes MIT files except where otherwise noted and MIT/GPLv2 for the linked kernel module; preserve all applicable notices |
| CUDA, L4T userspace, firmware | Separate NVIDIA terms. The project and recipe licenses do not grant rights over those binaries |

The OE4T superproject has no root LICENSE/COPYING file at the pinned revision,
but its top-level Makefile has an SPDX BSD-3-Clause header. Per-file terms remain
authoritative; submodule licenses are not a blanket license for unrelated files.
This project fetches the original build scripts instead of vendoring them.
The local Linux, host1x/BPMP, and nvgpu patches are GPL-2.0-only.

## Rules for later imports and distribution

- Preserve original patch authorship, commit metadata, SPDX headers, and notices.
- Record the exact source revision and target tree of every carried patch.
- Treat a patch containing upstream code as upstream-derived work, not
  automatically as original project code.
- Add required license texts/notices when vendoring code; do not replace
  upstream licenses with a blanket project license.
- Keep CUDA, firmware, BSP archives, and extracted proprietary binaries out of
  Git. Verify their actual download and redistribution terms before publishing
  packages, images, containers, or binary-cache artifacts.
- A private repository does not eliminate obligations attached to distribution.

This is a record of licensing boundaries, not a complete redistribution audit.
No blanket permission to publish the eventual combined image is claimed.
