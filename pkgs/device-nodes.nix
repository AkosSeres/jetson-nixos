# SPDX-License-Identifier: GPL-2.0-only
{ pkgs }:
pkgs.writeShellApplication {
  name = "jetson-xavier-device-nodes";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
  ];
  text = ''
    # nvdisplay registers major 195 without creating device-model objects.
    # A module-add udev event is insufficient when the module was already
    # loaded, so establish the two headless NVRM nodes in an ordered service.
    major=$(awk '$2 == "nvidia-frontend" { print $1 }' /proc/devices)
    if [[ "$major" != 195 || ! -d /sys/module/nvidia ]]; then
      echo "NVIDIA frontend is not registered on expected major 195" >&2
      exit 1
    fi
    create_node() {
      local node="$1" minor="$2" expected
      printf -v expected '%x:%x' "$major" "$minor"
      if [[ -e "$node" || -L "$node" ]]; then
        if [[ -L "$node" || ! -c "$node" || $(stat -c '%t:%T' "$node") != "$expected" ]]; then
          echo "Refusing to replace unexpected device path: $node" >&2
          exit 1
        fi
      else
        mknod -m 0660 "$node" c "$major" "$minor"
      fi
      chown root:video "$node"
      chmod 0660 "$node"
    }
    create_node /dev/nvidiactl 255
    create_node /dev/nvidia0 0
  '';
}
