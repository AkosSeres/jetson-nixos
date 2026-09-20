# Vendored Xavier patches

Copied unchanged from [CybrixSystems/armbian-build](https://github.com/CybrixSystems/armbian-build/tree/b673d05018528b6735408bd777f4e3bf33d5becf)
at revision `b673d05018528b6735408bd777f4e3bf33d5becf`.
The original input's NAR hash was
`sha256-8CBuSOPqEyUYgHjxOEa87Bo3kM0gNA+n4Dki2zlK/EQ=`.

| Local directory | Original directory | Target |
| --- | --- | --- |
| `linux/` | `patch/kernel/archive/uefi-arm64-6.18/` | Linux 6.18.46 |
| `nvidia-oot/` | `extensions/jetson-l4t/files/dkms/` | OE4T superproject `3428d01926de97ca8b0f25fe6edd9c76e19472a1` |

The ordered selection is in [`sources/patches.nix`](../../sources/patches.nix).
Original patch headers and author sign-offs are preserved. No Armbian build
scripts or installers are included.

These patches retain their upstream licenses. `LICENSE` is the
upstream Armbian GPLv2 text; `NOTICE` preserves target-source attribution.
`nvidia-oot/COPYING` is copied from the pinned nvdisplay submodule
`f48baa7a63e596a239e18be2dfae300aaf74d55b` and contains its MIT/GPLv2 terms.
Per-file licenses and notices remain authoritative.
