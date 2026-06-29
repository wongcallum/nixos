{
  config,
  pkgs,
  lib,
  ...
}:
{
  boot = {
    kernelModules = [ "kvm-intel" ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];

    extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
    initrd.kernelModules = [ "wl" ];
    kernel.sysctl."ibt" = "off";
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowInsecurePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "broadcom-sta" ];
  };

  hardware.facetimehd.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2e443e94-1772-41fa-b461-4304d32cedf1";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CFB8-BA42";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
