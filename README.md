<!-- SPDX-License-Identifier: MIT -->
# jetson-nixos

Experimental Nix packaging for a modern Linux kernel with CUDA on NVIDIA Jetson
AGX Xavier (T194 / GV11B, `sm_72`). This is not an NVIDIA-supported Xavier BSP.

## Current status

Source scaffold only. There is no kernel derivation, NVIDIA module build,
userspace overlay, NixOS module, or bootable system output yet. No hardware or
CUDA runtime validation has been performed with this repository.

The initial reproduction baseline is Linux **6.18.22**, the audited OE4T R36.5
out-of-tree sources, R36.4.4 driver userspace, and selected R35.6.5 Xavier firmware.
The old kernel point release is a comparison baseline, not the production target;
a later step must update within 6.18 LTS and repeat validation before deployment.

The first hardware milestone is headless CUDA, llama.cpp, NvMap accounting, and
GPU containers/K3s, with working networking, storage, and thermal control.
Display, camera, hardware video, TensorRT, and cuDNN are not first-milestone
requirements; TensorRT/cuDNN remain possible follow-up work, not promised support.

## Validate and fetch

On a Linux machine with Nix and flakes enabled:

```sh
nix flake check
nix build .#sources
nix eval --json .#lib.linuxSource
nix eval --json .#lib.patchSeries
```

The first invocation fetches the locked inputs, including all eight NVIDIA
submodules. `nix flake check` validates source layout and the 24 referenced patch
files; it does **not** compile code or prove that patches apply.
`nix build .#sources` additionally fetches and hash-checks the Linux archive.
It creates a `result` symlink to a source bundle, not a kernel or system image.
Neither command runs the Armbian installers or downloads CUDA/firmware packages.

Source packages and checks are exposed for `x86_64-linux` and `aarch64-linux`.
The former supports development on a workstation; it does not imply x86 Jetson
support or that cross-compilation has been implemented.

## Repository layout

- `flake.nix`, `flake.lock`: exact Git inputs and recursive source hashes.
- `sources/linux.nix`: Linux release archive URL and SHA-256.
- `sources/patches.nix`: ordered, upstream-relative patch inventories.
- `pkgs/sources.nix`: source-only fetch/bundle outputs.
- `checks/source-manifest.nix`: source presence and manifest checks.
- [Source provenance](docs/sources.md), [integration boundaries](docs/integration.md),
  and [licensing](docs/licensing.md).

Kernel/OOT derivations and NixOS modules will be added in subsequent changes;
there are no placeholder modules that silently select a kernel.

## Private repository access

Use Git-based HTTPS when consuming this repository with the GitHub credential
helper, for example during later infra integration:

```nix
inputs.jetson-nixos = {
  url = "git+https://github.com/AkosSeres/jetson-nixos.git?ref=main";
  inputs.nixpkgs.follows = "nixpkgs-homelab";
};
```

That input example alone does not enable any host feature. Each process fetching
private inputs needs its own access; do not assume a root rebuild, CI worker, or
remote evaluator inherits a desktop user's login. The GitHub `github:` fetcher
has separate token configuration; the Git credential helper is for `git+https:`.

Never put tokens in the flake, lock file, URLs, or Nix store. A private repository
does not make copied store sources confidential.

## License

Original code and documentation are MIT licensed; see [LICENSE](LICENSE).
Upstream sources and patches retain their own terms. In particular, this license
does not relicense Linux, NVIDIA drivers, CUDA, or firmware. See the
[licensing notes](docs/licensing.md) before importing or distributing artifacts.
