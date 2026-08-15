{
  config,
  inputs,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;
in
{
  flake.modules.nixos."hosts/nixos/liz" =
    { config, lib, ... }:
    {
      imports = [
        ./_disko.nix
        ./_networking.nix
        ./_console.nix
        ./_vfio.nix

        inputs.disko.nixosModules.default
        inputs.microvm.nixosModules.host
        (microvmLib.mkHostNetworking {
          n = 1;
          hostname = "vm-gallery";
        })
      ]
      ++ (with nixos; [
        uefi
        zram
        impermanence-zfs
        persistence
        sops

        callum
        colin

        ssh
        tailscale
        gateway
        libvirt
        metrics
        monitoring
        logs
        samba
        syncthing-server
        qbittorrent

        quadlet-productivity
        quadlet-media
        quadlet-automation
        quadlet-development
        quadlet-immich
        quadlet-hermes
      ]);

      microvm.vms.vm-gallery = {
        flake = inputs.self;
        restartIfChanged = true;
      };

      # _console.nix is a plain NixOS module and cannot see the flake-parts
      # config, so hand it the keys from this module's outer scope.
      _module.args.sshKeys = keys.callum;

      system.stateVersion = "25.11";
      # Bound to the ZFS pools, not the board — do NOT regenerate this across the
      # motherboard swap or every pool needs a forced import.
      networking.hostId = "19550836";

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "mpt3sas"
          "nvme"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
        kernelModules = [ "kvm-amd" ];
        supportedFilesystems = [ "zfs" ];
        # rpool and npool come in via fileSystems; these two do not.
        zfs.extraPools = [
          "tank"
          "scratch"
        ];
        zfs.forceImportRoot = false;
      };

      services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
        pools = [
          "tank"
          "scratch"
        ];
      };

      # Was never set, so the microcode line below silently evaluated to false.
      # It matters now: the B550 board needs rtl_nic firmware for its Realtek
      # 2.5GbE, and the Ryzen wants its microcode.
      hardware.enableRedistributableFirmware = true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      fileSystems."/mnt/media" = {
        device = "/dev/disk/by-uuid/0b878ab4-2310-4b8e-92e8-7ef5f47f75f8";
        fsType = "ext4";
      };

      modules = {
        samba.shares = {
          tank_colin = "/tank/colin";
          callum = "/tank/callum";
          photo = "/tank/photo";
          media = "/mnt/media";
          torrents = "/tank/torrents";
        };

        immich.externalLibraries = {
          photo = "/tank/photo";
          DCIM = "/tank/callum/syncthing/DCIM/Camera";
        };
      };
    };
}
