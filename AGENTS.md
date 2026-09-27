# jetson-nixos contributor guide

This is an independent, standalone flake.
Ordinary package expressions belong in `pkgs/`; reusable NixOS modules
belong in `modules/` and must be explicitly exported.

## Scope and safety

- The project targets a build-ready headless Xavier CUDA configuration.
  Distinguish source checks, package builds, complete-system builds, and hardware
  validation; none is a substitute for another.
- Keep host identities, secrets, workload/orchestration policy, and deployment
  wiring in consuming configurations, not this repository.
- Keep documentation and APIs independent of any particular consumer repository.
- Never reflash, repartition, deploy, reboot, or modify live hosts without an
  explicit deployment task and a confirmed recovery plan.
- Keep existing JetPack 5 configurations independent from this experimental
  port. Never fake an Orin identity to make a Xavier configuration evaluate.

## Sources and licensing

- Read `docs/sources.md`, `docs/integration.md`, and `docs/licensing.md` before
  changing source pins, patch inventories, or packaging boundaries.
- Pin revisions and content hashes. NVIDIA submodules follow committed gitlinks,
  never `git submodule update --remote` or floating branch tips.
- Put Linux patches on the Linux source and OOT patches on the matching OOT tree.
  Do not pass vendor-module patches through `boot.kernelPatches`.
- Preserve upstream attribution and per-file license terms. Do not commit
  proprietary binaries, firmware, credentials, or copied host configuration.

## Workflow

- Work on feature branches; do not commit or push directly to `main`.
- Preserve unrelated work. Use GitHub pull requests when publication is requested.
- For scaffold changes, run `nix flake check`, `nix build .#sources`, formatting
  checks on changed Nix files, and `git diff --check`.
- Document exactly which checks ran and what remains untested. Do not add empty
  kernel/module outputs just to make an interface appear complete.
