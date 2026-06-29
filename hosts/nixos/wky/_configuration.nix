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

  systemd.services.limine-branding = {
    description = "Set Limine branding from local file";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = "/boot";
    path = with pkgs; [
      coreutils
      gnugrep
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      conf=/boot/limine/limine.conf
      brand=/var/lib/limine-branding
      [ -r "$brand" ] && [ -w "$conf" ] || exit 0
      val=$(head -n1 "$brand")
      tmp=$(mktemp)
      {
        printf 'interface_branding: %s\n' "$val"
        grep -v '^interface_branding:' "$conf"
      } > "$tmp"
      cat "$tmp" > "$conf"
      rm -f "$tmp"
    '';
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
