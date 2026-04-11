{
  flake.nixosModules.liz-configuration =
    {
      lib,
      config,
      ...
    }:
    {
      system.stateVersion = "25.11";
      networking.hostId = "19550836";

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "mpt3sas"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      boot.supportedFilesystems = [ "zfs" ];
      boot.zfs.extraPools = [ "tank" ];
      fileSystems."/mnt/media" = {
        device = "/dev/disk/by-uuid/0b878ab4-2310-4b8e-92e8-7ef5f47f75f8";
        fsType = "ext4";
      };
    };
}
