{
  config,
  inputs,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos."hosts/nixos/liz" =
    { config, lib, ... }:
    {
      imports = [
        ./_disko.nix
        ./_networking.nix

        inputs.disko.nixosModules.default
        inputs.microvm.nixosModules.host
        (microvmLib.mkHostNetworking {
          n = 1;
          hostname = "vm-gallery";
        })
        (microvmLib.mkHostNetworking {
          n = 2;
          hostname = "vm-jenkins";
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
      ]);

      microvm.vms.vm-gallery = {
        flake = inputs.self;
        restartIfChanged = true;
      };

      microvm.vms.vm-jenkins = {
        flake = inputs.self;
        restartIfChanged = true;
      };

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
        kernelModules = [ "kvm-intel" ];
        supportedFilesystems = [ "zfs" ];
        zfs.extraPools = [ "tank" ];
        zfs.forceImportRoot = false;
      };

      services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
        pools = [ "tank" ];
      };

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
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

        # TODO: find a way to move this somewhere else
        gateway.services.development-jenkins = {
          name = "Jenkins";
          domainName = "jenkins";
          addr = "10.0.0.3:8080";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jenkins.png";
          category = "Development";
        };
      };
    };
}
