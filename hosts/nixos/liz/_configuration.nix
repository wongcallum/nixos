{
  lib,
  config,
  ...
}:
{
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

  modules.samba.shares = {
    tank_colin = "/tank/colin";
    callum = "/tank/callum";
    photo = "/tank/photo";
    media = "/mnt/media";
    torrents = "/tank/torrents";
  };

  modules.immich.externalLibraries = {
    photo = "/tank/photo";
    DCIM = "/tank/callum/syncthing/DCIM/Camera";
  };
}
