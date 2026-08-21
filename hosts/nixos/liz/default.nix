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
        ./_windows-vm.nix

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
        sensors
        watchdog
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

        radicale
        trilium
        memos
        quadlet-productivity
        quadlet-media
        quadlet-automation
        quadlet-development
        quadlet-immich
        quadlet-hermes
        quadlet-gotosocial
      ]);

      microvm.vms.vm-gallery = {
        flake = inputs.self;
        restartIfChanged = true;
      };

      _module.args.sshKeys = keys.callum;

      system.stateVersion = "25.11";
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
        zfs.extraPools = [
          "tank"
          "scratch"
        ];
        zfs.forceImportRoot = false;

        # Demand misses barely improved between the previous 4.7 GiB ARC and 28 GiB;
        # 8 GiB leaves headroom while preserving RAM for page cache and the Windows VM.
        # ZFS first loads in the initrd, so the cap must be a modprobe option.
        extraModprobeConfig = "options zfs zfs_arc_max=8589934592";
      };

      services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
        pools = [
          "tank"
          "scratch"
        ];
      };

      hardware.enableRedistributableFirmware = true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      fileSystems."/mnt/media" = {
        device = "/dev/disk/by-uuid/0b878ab4-2310-4b8e-92e8-7ef5f47f75f8";
        fsType = "ext4";
      };

      modules = {
        sensors.chips = [ "nct6775" ];
        watchdog.driver = "sp5100_tco";

        samba.shares = {
          tank_colin = "/tank/colin";
          callum = "/tank/callum";
          photo = "/tank/photo";
          media = "/mnt/media";
          torrents = "/tank/torrents";

          games = "/scratch/games";
        };

        immich.externalLibraries = {
          photo = "/tank/photo";
          DCIM = "/tank/callum/syncthing/DCIM/Camera";
        };
      };
    };
}
