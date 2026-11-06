{
  config,
  inputs,
  vmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys nixosConfigurations;
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
        ./_persist-backup.nix

        inputs.disko.nixosModules.default
        inputs.microvm.nixosModules.host
      ]
      ++ map (hostname: vmLib.mkHostLink hostname { }) (lib.attrNames vmLib.microvmGuests)
      ++ map vmLib.mkGuestStorage (lib.attrNames vmLib.microvmGuests)
      ++ (with nixos; [
        uefi
        zram
        sensors
        watchdog
        impermanence-zfs
        persistence
        secrets

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
        thsconline
        offsite-backup-source

        kanzo
        radicale
        trilium
        quadlet-productivity
        quadlet-leafwiki
        quadlet-media
        quadlet-automation
        quadlet-development
        quadlet-immich
        quadlet-lobehub

        attic
        cliproxyapi

        vm-ci-host
        vm-gpu-host
        cameras
      ]);

      microvm.vms = lib.mapAttrs (hostname: _: {
        evaluatedConfig = nixosConfigurations.${hostname};
        restartIfChanged = true;
      }) vmLib.microvmGuests;

      _module.args = {
        sshKeys = keys.callum;
        inherit vmLib;
      };

      # The mirror share lives on tank, which isn't a systemd mount.
      systemd.services."microvm-virtiofsd@vm-thsconline".after = [ "zfs-mount.service" ];

      # Keep CI off the cores the GPU VM is pinned to.
      modules.qemuVms.vm-ci.allowedCpus = "0-2 6-8";

      virtualisation.quadlet.containers.media-jellyfin.containerConfig.publishPorts = [
        "192.168.0.2:8096:8096"
      ];

      environment.persistence.${config.modules.persistence.persistDir}.directories = [
        "/var/lib/libvirt"
      ];

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

        # Misses barely dropped with more than 4.7 GiB of ARC. ZFS loads in the
        # initrd, so the cap has to be a modprobe option.
        extraModprobeConfig = "options zfs zfs_arc_max=8589934592";
      };

      nix = {
        settings = {
          max-jobs = 1;
          cores = 8;

          min-free = 21474836480; # 20 GiB
          max-free = 64424509440; # 60 GiB
        };
      };

      programs.nh.clean.dates = lib.mkForce "daily";

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

      # The root is rolled back on boot.
      virtualisation.containers.storage.settings.storage.graphroot = config.utils.cacheDir "containers";

      modules = {
        persistence.cacheDir = "/cache";
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
