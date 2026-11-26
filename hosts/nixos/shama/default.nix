{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.shama = "unstable";

  flake.modules.nixos."hosts/nixos/shama" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        ./_audio.nix
        ./_disko.nix
        ./_packages.nix

        inputs.chaotic.nixosModules.default
        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        impermanence-btrfs
        callum
        desktop
        syncthing-desktop
        laptop
        autofs
        nix-monitored
        freesmlauncher
        libvirt
        docker
        keyd
        bluetooth
      ]);

      system.stateVersion = "26.05";

      # Travels; automatic-timezoned follows the location instead.
      time.timeZone = lib.mkForce null;
      services.automatic-timezoned.enable = true;

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";

        # OpenVINO needs this for the NPU.
        ZE_ENABLE_ALT_DRIVERS = "/run/opengl-driver/lib/libze_intel_npu.so.1";
      };

      modules = {
        syncthing-desktop.user = "callum";
        firefox.transparency.enableToolbox = true;
      };

      boot = {
        kernelPackages = pkgs.linuxPackages_cachyos;
        kernelModules = [
          "kvm-intel"
          "uinput"
          "ntsync"
        ];

        initrd = {
          availableKernelModules = [
            "nvme"
            "xhci_pci"
            "thunderbolt"
            "usb_storage"
            "usbhid"
            "sd_mod"
          ];

          systemd.services.impermanence-root-rollback.after = [
            "systemd-hibernate-resume.service"
          ];
        };

        loader.efi.canTouchEfiVariables = true;
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        cpu.intel.npu.enable = true;

        graphics = {
          enable = true;
          enable32Bit = true;
          extraPackages = with pkgs; [
            intel-media-driver
            vpl-gpu-rt
          ];
        };
      };
    };
}
