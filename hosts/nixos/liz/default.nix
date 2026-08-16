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

        # Cap the ARC at 8 GiB. Left at the default it takes almost everything:
        # `zfs_arc_max=0` resolves to `MAX(allmem * 5/8, allmem - 1GiB)` on Linux —
        # not the "half of RAM" the older docs claim — which is a 61.7 GiB ceiling
        # out of 62.7 GiB here. Measured rather than guessed: `c_max` came out at
        # exactly MemTotal minus 1 GiB on both the 16 GB Z370 and this board.
        #
        # 8 GiB because that is where the measurements stop improving. Going from
        # the 4.7 GiB ARC the old box settled at to the 28 GiB this one reached
        # bought ~7 fewer *demand* misses per second (data 1.72 -> 0.91/s, metadata
        # 6.13 -> 0.14/s) — under 1 MB/s of avoided reads. What actually misses is
        # prefetch, 34/s then and 15/s now: sequential first-touch reads of torrents
        # and media, which no cache size can help. So 8 GiB is comfortably above the
        # 4.7 GiB that demonstrably worked, holds the ~2.3 GiB metadata working set
        # without squeezing data, and nothing beyond it is worth the RAM.
        #
        # That RAM has better uses. qBittorrent's libtorrent mmaps its torrents and
        # holds ~15 GiB of page cache double-caching blocks ARC already has — ARC
        # peaked at 34.6 GiB on the first boot and was already losing ground to it —
        # and the phase 05 Windows guest wants 24-32 GB.
        #
        # This has to be modprobe config, not a runtime write: zfs is loaded in the
        # initrd to import rpool, and that load is the only point modprobe.d is
        # consulted. systemd's initrd carries /etc/modprobe.d/nixos.conf, so it
        # applies there.
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
