<!-- SPDX-License-Identifier: GPL-2.0-only -->
# NVIDIA R36.5.2 backports

These are unchanged upstream email patches for the pinned OE4T R36.5 source
trees. [manifest.json](manifest.json) records each exact NVIDIA commit, download
URL, target subdirectory and SHA-256. The ordered Nix inventories are derived
from that manifest in [sources/patches.nix](../../sources/patches.nix).

The three NvMap patches fix invalid-handle dereferences, unchecked ranges and
boundary offsets in `NVMAP_IOC_GET_FD_FOR_RANGE_FROM_LIST`. NVIDIA identifies
these under bug 6355805. They validate page alignment and overflow before
copying page references between handles; ordinary physical-page allocation,
page accounting and allocation-retry policy are unchanged.

The eight nvgpu patches address NVIDIA bug 6355239: checked arithmetic in
GV11B debug-register handling, AS allocation, virtual-memory remapping,
copy-engine addressing and PRAMIN/LTC handling. They replace selected unchecked
or fatal arithmetic operations with validated calculations and error returns.
Retain the complete eight-patch series: some earlier commits use helper
functions introduced later in the upstream series. This is one buildable
backport group, not eight independently buildable intermediate states.

`pkgs/nvidia-oot.nix` applies the existing 19 superproject patches first, then
these unchanged patches within `nvidia-oot/` and `nvgpu/`, using zero fuzz.
Applying from each subdirectory preserves the original upstream paths and bytes.
The source-manifest check verifies patch presence, recorded hashes and counts.
The source-only bundle includes this directory and its licensing notices.

Source applicability is separate from kernel/module compilation and hardware
validation. A candidate requires a matching OOT build, complete-system build,
coordinated reboot and CUDA/container/NvMap regression checks. These backports
do not claim to fix every NVIDIA security issue or the separate stmmac RX
page-pool teardown leak.

The patches retain two upstream limitations: PRAMIN's outer access loop still
discards callback error returns, and malformed virtual-pool teardown can skip
ordinary memory-pool cleanup. The added bounds checks do not establish complete
error propagation or leak-free handling of every corrupted state. No CVE IDs
are assigned by these patch headers; describe the exact vendor fixes rather
than claiming complete R36.5.2 security coverage.

See [NOTICE](NOTICE), [GPLv2](COPYING.GPL-2.0-only), [MIT](COPYING.MIT) and the
repository [licensing boundaries](../../docs/licensing.md).
