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
          modesetting.enable = true;
          open = false;
        };
      };
    };
}
