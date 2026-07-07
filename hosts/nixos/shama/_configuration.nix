{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  # NixOS automatically creates with `btrfs filesystem mkswapfile`
  # priority is automatically set below zram
  swapDevices = [
    {
      device = "/persist/swapfile";
      size = 32 * 1024; # MiB
    }
  ];

  modules.laptop.suspendThenHibernate.enable = true;

  boot = {
    # arrow lake needs very recent kernel
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [
      "kvm-intel"
      "uinput"
    ];

    kernelPatches = [
      {
        name = "cs35l41-omnibook7-8e3b";
        patch = pkgs.fetchpatch {
          url = "https://lore.kernel.org/linux-sound/0108019f32ada4d0-8ff2c576-8eb9-4ac4-803e-8ff4e1ce57d3-000000@ap-southeast-2.amazonses.com/raw";
          hash = "sha256-oN9tNA0jeRLel1Rv8gjjNc7iLTBTaYxTZ8ibRhuEjCI=";
        };
      }
      {
        name = "alc245-omnibook7-8e3b";
        patch = pkgs.fetchpatch {
          url = "https://lore.kernel.org/linux-sound/0108019f32adb483-2c606373-6a9f-483c-ba13-c413bc432170-000000@ap-southeast-2.amazonses.com/raw";
          hash = "sha256-VnzxUqQZGyTrkLcGXCU7/6xPLz/U4Pf9svUu1upNcF8=";
        };
      }
    ];

    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];

      systemd.services.impermanence-root-rollback.after = [
        "systemd-hibernate-resume.service"
      ];
    };

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
    cpu.intel.npu.enable = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    };

    opentabletdriver.enable = true;
    uinput.enable = true;
  };

  # crashes if service starts before DISPLAY/WAYLAND_DISPLAY are set
  systemd.user.services.opentabletdriver.after = [ "graphical-session.target" ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";

    # needed for openvino npu device
    ZE_ENABLE_ALT_DRIVERS = "/run/opengl-driver/lib/libze_intel_npu.so.1";
  };
}
