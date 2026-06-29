{
  config,
  pkgs,
  lib,
  ...
}:
let
  aixoid9-f16 = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/viler-int10h/vga-text-mode-fonts/ab3965599eb3d0de9834fa9c26942b4e4843a42b/FONTS/AIXOID9.F16";
    hash = "sha256-+nOBq3pTPm74LnJNTPcwYNwC4befR/EBa7NkAiOxBaQ=";
  };
in
{
  boot = {
    loader = {
      timeout = 10;
      limine = {
        enable = true;

        additionalFiles."fonts/AIXOID9.F16" = aixoid9-f16;
        extraConfig = "term_font: boot():/limine/fonts/AIXOID9.F16";

        # theme from https://github.com/diegons490/cachyos-limine-theme
        style = {
          wallpapers = [ pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt.gnomeFilePath ];
          interface.branding = "wky";
          graphicalTerminal = {
            palette = "1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4";
            brightPalette = "585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4";
            background = "ffffffff";
            foreground = "cdd6f4";
            brightBackground = "ffffffff";
            brightForeground = "cdd6f4";
          };
        };
      };
    };

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
