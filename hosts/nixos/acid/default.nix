{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.acid = "unstable";

  flake.modules.nixos."hosts/nixos/acid" =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [
        ./_disko.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        zram
        impermanence-btrfs
        callum
        ssh
        tailscale

        dev
        t3code
      ]);

      system.stateVersion = "26.05";

      boot = {
        # OpenCore owns the boot order and chainloads Limine's removable path.
        loader.efi.canTouchEfiVariables = false;

        blacklistedKernelModules = [ "nouveau" ];

        initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        kernelModules = [ "kvm-intel" ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

      networking.useNetworkd = true;
      systemd.network = {
        enable = true;
        networks."10-eth" = {
          matchConfig.Type = "ether";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };
        wait-online.anyInterface = true;
      };

      systemd.targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
        enable = false;
      });

      networking.wireless.iwd.enable = true;

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
        settings.publish = {
          disable-publishing = false;
          publish-addresses = true;
        };
      };
    };
}
