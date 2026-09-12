# jetson-nixos contributor guide

This is a standalone flake, not an infra flake-parts/import-tree subtree.
Ordinary package expressions belong in `pkgs/`; future reusable NixOS modules
belong in `modules/` and must be explicitly exported.

## Scope and safety

- The current milestone is source scaffolding. Do not imply that a source fetch
  or metadata check is a kernel build, boot test, or CUDA validation.
- Keep host identities, secrets, cluster policy, and deployment wiring in infra.
- Never reflash, repartition, deploy, reboot, or modify live hosts without an
  explicit deployment task and a confirmed recovery plan.
- Keep production JetPack 5 configurations independent from this experimental
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
