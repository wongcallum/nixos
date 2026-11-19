{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.wky = "unstable";

  flake.modules.nixos."hosts/nixos/wky" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        ./_disko.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        impermanence-btrfs
        callum
        ssh
        desktop
        laptop
        keyd
        bluetooth
      ]);

      system.stateVersion = "26.05";

      boot = {
        kernelModules = [
          "kvm-intel"
          "wl"
        ];
        extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
        blacklistedKernelModules = [
          "b43"
          "bcma"
          "brcmfmac"
          "brcmsmac"
          "ssb"
        ];

        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];

        # Mac firmware only boots the removable path.
        loader.limine.efiInstallAsRemovable = true;
      };

      nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "broadcom-sta";

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        facetimehd.enable = true;

        graphics = {
          enable = true;
          extraPackages = [ pkgs.intel-media-driver ];
        };
      };

      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

      time.timeZone = lib.mkForce null;

      services = {
        mbpfan.enable = true;
        automatic-timezoned.enable = true;
        # Public wifi; SSH is reachable over Tailscale only.
        openssh.openFirewall = false;
      };
    };
}
