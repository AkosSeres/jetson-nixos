# SPDX-License-Identifier: GPL-2.0-only
{ overlay }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.jetson-xavier;
  stack = pkgs.jetson-xavier;
  userspace = stack.userspace;
  runtime = userspace.containerRuntime;
  mount = path: {
    hostPath = toString path;
    containerPath = toString path;
  };
in
{
  # Transform the final DTB package, after NixOS filters/applies overlays.
  # Padding dtbSource alone is insufficient: applying an overlay repacks it.
  options.hardware.deviceTree.package = lib.mkOption {
    apply =
      dtbs:
      if cfg.enable && dtbs != null then
        import ../pkgs/uefi-dtb.nix {
          inherit pkgs dtbs;
          inherit (config.hardware.deviceTree) name;
        }
      else
        dtbs;
  };

  options.hardware.jetson-xavier = {
    enable = lib.mkEnableOption "the experimental headless AGX Xavier Linux 6.18/CUDA stack";
    containers.enable = lib.mkEnableOption "the matching Jetson CSV container driver integration";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
            message = "hardware.jetson-xavier requires a native aarch64-linux host configuration.";
          }
          {
            assertion = !config.services.xserver.enable;
            message = "The first Xavier milestone is headless; desktop integration has not been ported.";
          }
          {
            assertion = !config.hardware.nvidia.enabled;
            message = "The Xavier module provides its own driver; do not enable the desktop/SBSA NVIDIA module.";
          }
        ];

        nixpkgs.overlays = [
          overlay
          (final: _: { cudaPackages = final.jetson-xavier.cudaPackages; })
        ];
        nixpkgs.config = {
          cudaCapabilities = [ "7.2" ];
          allowUnfreePackages = [
            "xavier-firmware"
            "xavier-gv11b-firmware"
            "xavier-xusb-firmware"
            "jetson-xavier-udev-rules"
          ];
        };

        boot.kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor stack.kernel);
        # NixOS may add configuration patches to kernelPackages.kernel. Build
        # against that final derivation, not the unextended package-set kernel.
        boot.extraModulePackages = [ (stack.mkNvidiaOot config.boot.kernelPackages.kernel) ];
        boot.kernelModules = [
          "nvmap"
          "host1x"
          "host1x-nvhost"
          "host1x-fence"
          "nvgpu"
          "nvidia"
        ];
        boot.blacklistedKernelModules = [
          "nouveau"
          "nova_core"
          "nova_drm"
        ];
        boot.kernelParams = [
          "console=ttyTCU0,115200n8"
          "video=efifb:off"
        ];
        boot.extraModprobeConfig = ''
          options nvgpu devfreq_timer=delayed
        '';
        boot.initrd.availableKernelModules = [
          "nvme"
          "nvme-core"
          "pcie-tegra194"
          "phy-tegra194-p2u"
          "xhci-tegra"
          "ucsi_ccg"
          "typec_ucsi"
        ];

        hardware.deviceTree = {
          enable = true;
          name = "nvidia/tegra194-p2972-0000.dtb";
        };
        hardware.firmware = [ stack.firmware.combined ];

        # This exposes libcuda and its driver dependencies without enabling the
        # desktop/SBSA NVIDIA module or importing JetPack's kernel/flash modules.
        hardware.graphics = {
          enable = true;
          package = userspace.l4t-3d-core;
          extraPackages = [
            userspace.l4t-core
            userspace.l4t-cuda
            userspace.l4t-gbm
          ];
        };
        hardware.nvidia.package = userspace.l4t-3d-core;
        environment.etc."nv_tegra_release".source = "${userspace.l4t-core}/etc/nv_tegra_release";
        environment.systemPackages = [ stack.cuda-smoke ];

        # Preserve the vendor's separate video/debug/root permissions, including
        # the R36 nvgpu/igpu0 ABI. Do not make debug/scheduler nodes video-writable.
        services.udev.packages = [
          (import ../pkgs/udev-rules.nix {
            inherit pkgs;
            inherit (userspace) l4t-init;
          })
        ];
        users.groups.debug = { };
        systemd.services.jetson-xavier-device-nodes = {
          description = "Create headless Xavier NVRM device nodes";
          after = [ "systemd-modules-load.service" ];
          before = [ "nvidia-container-toolkit-cdi-generator.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.getExe (import ../pkgs/device-nodes.nix { inherit pkgs; });
          };
        };
      }
      (lib.mkIf cfg.containers.enable {
        hardware.nvidia-container-toolkit = {
          enable = true;
          suppressNvidiaDriverAssertion = true;
          csv-files = runtime.csvFiles;
          discovery-mode = lib.mkForce runtime.discoveryMode;
          mount-nvidia-executables = lib.mkForce false;
          mount-nvidia-docker-1-directories = lib.mkForce false;
          extraArgs = [
            "--driver-root"
            (toString runtime.driverRoot)
            "--dev-root"
            runtime.deviceRoot
          ]
          ++ lib.concatMap (pattern: [
            "--csv.ignore-pattern"
            pattern
          ]) runtime.csvIgnorePatterns;
          # Preserve store symlink targets behind /run/opengl-driver. The CSV
          # driver root and all of these packages come from the same R36.4 pin.
          mounts = lib.mkForce (
            map mount (
              [
                "${lib.getLib pkgs.glibc}/lib"
                "${lib.getLib pkgs.glibc}/lib64"
                pkgs.addDriverRunpath.driverLink
              ]
              ++ userspace.driverPackages
            )
          );
        };
        systemd.services.nvidia-container-toolkit-cdi-generator = {
          requires = [ "jetson-xavier-device-nodes.service" ];
          after = [ "jetson-xavier-device-nodes.service" ];
          before = [
            "docker.service"
            "podman.service"
          ];
        };
      })
    ]
  );
}
