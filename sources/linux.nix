# SPDX-License-Identifier: MIT
{
  # Keep the exact point release validated on both AGX Xavier nodes. Point
  # updates are separate experiments and must pass patch, build, boot, CUDA,
  # networking, and sustained-workload validation before replacing this pin.
  version = "6.18.46";
  url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.46.tar.xz";
  hash = "sha256-9dRLk4CLAswpacVAS6CB2XUjcZyf0rot5tsxi0FBzKA=";
}
