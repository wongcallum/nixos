{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  boot = {
    # arrow lake needs very recent kernel
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "kvm-intel" ];
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];

    # chainload the Windows bootloader on the separate Windows ESP
    loader.limine.extraEntries = ''
      /Windows
          protocol: efi
          path: guid(cf90b43d-bb12-4ef9-9fde-8e5c7c3adcff):/EFI/Microsoft/Boot/bootmgfw.efi
    '';

    # allow limine to take over the world
    loader.efi.canTouchEfiVariables = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    };
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
