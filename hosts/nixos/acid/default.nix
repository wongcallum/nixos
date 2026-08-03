{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.acid = "unstable";

  flake.modules.nixos."hosts/nixos/acid" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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
        autofs
        cryptomatord
        zed
        freesmlauncher
        disk-utils
        nix-monitored
        nix-discord-rpc
        llama-cpp

        impermanence-btrfs

        desktop
        opentabletdriver

        keyd
        libvirt
        docker
        bluetooth
        thunderbird
        syncthing-desktop
        helium
        trilium-desktop
      ]);

      system.stateVersion = "26.05";
      services = {

        resolved.enable = true;
        xserver.videoDrivers = [ "nvidia" ];
      };
      systemd = {

        user.services.niri.environment.NIRI_CONFIG = "/etc/niri/acid.kdl";
      };

      environment.etc."niri/acid.kdl".text = ''
        include optional=true "/home/callum/.config/niri/config.kdl";

        debug {
          render-drm-device "/dev/dri/by-path/pci-0000:04:00.0-render"
          ignore-drm-device "/dev/dri/by-path/pci-0000:07:00.0-render"
        }
      '';

      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
      };

      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        (final: prev: {
          nnn = prev.nnn.overrideAttrs {
            version = "5.3-unstable-2026-05-29";
            src = final.fetchFromGitHub {
              owner = "jarun";
              repo = "nnn";
              rev = "2f1d36273ac256723781be82088d6f95edbbe2e5";
              sha256 = "sha256-u77QZOlzLZ4CDjZmuGnyEF9avOoMbLxnRO7M2JHTb1g=";
            };
          };
        })
      ];

      networking.networkmanager.enable = true;
      documentation.man.cache.enable = false;

      modules = {
        syncthing-desktop.user = "callum";
        firefox.transparency = {
          enableToolbox = true;
          enablePage = true;
        };
      };

      users.users.callum.extraGroups = [
        "networkmanager"
        "adbusers"
      ];
      users.users.callum.initialPassword = lib.mkForce null;

      fileSystems."/games" = {
        device = "/dev/disk/by-uuid/6d374cf5-77a0-4d97-8f25-86622c9e74f0";
        fsType = "ext4";
      };

      boot = {
        # Keep the text console (and tuigreet) on the 1060's framebuffer.
        # The GTX 1060 currently exposes fb0; the CUDA-only 3060 has no fbdev.
        kernelParams = [ "fbcon=map:0" ];

        loader.efi.canTouchEfiVariables = true;

        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
      };

      specialisation.LinuxLatest.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        graphics.enable = true;

        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          modesetting.enable = true;
          open = false;
          powerManagement.enable = true;
        };
      };

    };
}
