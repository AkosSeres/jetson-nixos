<!-- SPDX-License-Identifier: MIT -->
# jetson-nixos

Experimental Nix packaging for a modern Linux kernel with CUDA on NVIDIA Jetson
AGX Xavier (T194 / GV11B, `sm_72`). This is not an NVIDIA-supported Xavier BSP.

## Current status

The experimental stack has booted and passed CUDA and container workload tests
on two AGX Xavier systems. The final EQOS tuning has a dated canary observation
in [the validation record](docs/validation.md); the second system runs an older
configuration. Full platform and sustained-workload validation is incomplete.

The known-good baseline uses Linux **6.18.46**, the audited OE4T R36.5
out-of-tree sources, R36.4.4 driver userspace, and selected R35.6.5 Xavier firmware.
The community reference used 6.18.22. Point releases remain explicitly pinned and
must pass the full patch, build, boot, CUDA, networking, and sustained-workload
validation gates before replacing the validated 6.18.46 pin.

The first hardware milestone is headless CUDA, NvMap accounting, and
GPU containers/K3s, with working networking, storage, and thermal control.
llama.cpp is an optional later workload, not a first-milestone requirement.
Display, camera, hardware video, TensorRT, and cuDNN are not first-milestone
requirements; TensorRT/cuDNN remain possible follow-up work, not promised support.

## Build and check

On a Linux machine with Nix and flakes enabled:

```sh
nix flake check --no-build --all-systems
nix build .#checks.x86_64-linux.source-manifest
nix build .#checks.x86_64-linux.kernel-contract
nix build .#checks.x86_64-linux.uefi-dtb
nix build .#sources
nix build .#nvidia-oot --max-jobs 1 --cores 6
```

On x86_64, `kernel` and `nvidia-oot` cross-build for ARM64. On a Xavier those
outputs build natively. The kernel contract builds and checks the generated
configuration; it does not compile the kernel. `nvidia-oot` builds the kernel,
DTBs, and external modules. It can take considerable time and disk space.

CUDA userspace and `cuda-smoke` are **native aarch64** derivations, even when
evaluated from x86. Build them on a native builder, with modest parallelism on
an in-use Xavier:

```sh
nix build .#userspace .#firmware .#cuda-smoke --max-jobs 1 --cores 2
```

The smoke test allocates 4 MiB on the GPU and verifies a small kernel result.
Run it only after booting the matching experimental system. Compilation does
not prove driver/runtime compatibility. See [validation](docs/validation.md)
for the evidence and remaining gates.

`sources` remains a source-only bundle and never runs the Armbian installers.
The firmware and userspace outputs fetch NVIDIA binaries under their own terms.

## NixOS integration

Import `inputs.jetson-nixos.nixosModules.xavier` and enable
`hardware.jetson-xavier.enable`. Set `hardware.jetson-xavier.containers.enable`
for matching CSV-based NVIDIA Container Toolkit integration. The module is
limited to the AGX Xavier developer kit and does not flash firmware.

It owns kernel/DTB/module selection, isolated CUDA 12.6 packages, R36.4.4 driver
libraries, and selected R35.6.5 firmware. OOT owns host1x/tegra-drm; mainline owns
BPMP and MC/EMC. A kernel-managed fan curve replaces vendor nvfancontrol.
The final mainline DTB receives 64 KiB of padding for UEFI updates, after any
NixOS overlays. This does not rebuild the kernel; the initial FDT boot failure
and its correction are recorded in the archived bring-up notes.

Keep hostnames, disks, users, secrets, K3s policy, llama.cpp and boot selection
in the consuming NixOS configuration. Validate a candidate before promoting it
to normal host outputs, retaining known-good boot generations for recovery.
Use `nixos-rebuild boot` and a coordinated reboot for kernel/driver changes.

To share the consumer's package set, set
`inputs.jetson-nixos.inputs.nixpkgs.follows = "nixpkgs"` (or its host-specific
input name). This also changes the private CUDA/userspace package set; validate
the resulting closure. Use `lib.mkKernelContract` to check the final NixOS
kernel after consumer configuration changes.

## Repository layout

- `flake.nix`, `flake.lock`: exact Git inputs and recursive source hashes.
- `sources/linux.nix`: Linux release archive URL and SHA-256.
- `sources/patches.nix`: ordered, upstream-relative patch inventories.
- `pkgs/sources.nix`: source-only fetch/bundle outputs.
- `pkgs/kernel*.nix`, `pkgs/nvidia-oot.nix`: kernel/config/module packaging.
- `overlays/`, `pkgs/userspace.nix`, `pkgs/firmware.nix`: isolated package scopes.
- `modules/xavier.nix`: opt-in headless NixOS module.
- `patches/`: local, separately licensed Linux/OOT adaptations.
- `checks/`, `tests/`: source/config checks and the CUDA smoke test.
- [Source provenance](docs/sources.md), [integration boundaries](docs/integration.md),
  and [licensing](docs/licensing.md).

## Private repository access

Use Git-based HTTPS when consuming this repository with the GitHub credential
helper:

```nix
inputs.jetson-nixos = {
  url = "git+https://github.com/AkosSeres/jetson-nixos.git?ref=main";
};
```

That input example alone does not enable any host feature. Each process fetching
private inputs needs its own access; do not assume a root rebuild, CI worker, or
remote evaluator inherits a desktop user's login. The GitHub `github:` fetcher
has separate token configuration; the Git credential helper is for `git+https:`.

Never put tokens in the flake, lock file, URLs, or Nix store. A private repository
does not make copied store sources confidential.

## License

Original Nix code and documentation are MIT licensed; see [LICENSE](LICENSE).
Upstream sources and patches retain their own terms. In particular, this license
does not relicense Linux, NVIDIA drivers, CUDA, or firmware. See the
[licensing notes](docs/licensing.md) before importing or distributing artifacts.
