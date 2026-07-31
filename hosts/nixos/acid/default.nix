{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.acid = "unstable";

  flake.modules.nixos."hosts/nixos/acid" =
    { config, lib, ... }:
    {
      imports = [
        ./_disko.nix
        ./_packages.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        console-font
        zram

        callum
        ssh
        tailscale

        impermanence-btrfs

        audio
        desktop
        niri
        fonts
        bluetooth
        firefox
        ghostty
      ]);

      system.stateVersion = "26.05";

      systemd.user.services.niri.environment.NIRI_CONFIG = "/etc/niri/acid.kdl";
      environment.etc."niri/acid.kdl".text = ''
        include optional=true "/home/callum/.config/niri/config.kdl";

        debug {
          render-drm-device "/dev/dri/by-path/pci-0000:04:00.0-render"
          ignore-drm-device "/dev/dri/by-path/pci-0000:07:00.0-render"
        }
      '';

      nixpkgs.config.allowUnfree = true;

      networking.networkmanager.enable = true;
      services.resolved.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];

      users.users.callum.extraGroups = [ "networkmanager" ];
      users.users.callum.initialPassword = lib.mkForce null;

      fileSystems."/games" = {
        device = "/dev/disk/by-uuid/6d374cf5-77a0-4d97-8f25-86622c9e74f0";
        fsType = "ext4";
      };

      boot = {
        # Keep the text console (and tuigreet) on the 1060's framebuffer.
        # fb0 is the CUDA-only 3060; fb1 is the display 1060.
        kernelParams = [ "fbcon=map:1" ];

        loader.efi.canTouchEfiVariables = true;

        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        graphics.enable = true;

        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          modesetting.enable = true;
          open = false;
        };
      };
    };
}
