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
        ./_audio-always-on.nix
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
        tea
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
      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
      };

      nixpkgs.config.allowUnfree = true;

      networking.networkmanager.enable = true;

      modules = {
        syncthing-desktop.user = "callum";
        firefox.transparency = {
          enableToolbox = true;
          enablePage = false;
        };
      };

      users.users.callum.extraGroups = [
        "networkmanager"
        "adbusers"
      ];

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

      specialisation.LinuxLatest.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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
