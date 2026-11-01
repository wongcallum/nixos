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
        impermanence-btrfs
        callum
        ssh
        tailscale
      ]);

      system.stateVersion = "26.05";

      boot = {
        # OpenCore owns the firmware boot order and chainloads Limine from
        # acid's own ESP, so Limine installs to the removable path
        loader.efi.canTouchEfiVariables = false;

        # the NVIDIA card stays installed but unused
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

      # Reachable over the LAN until tailscale is logged in: DHCP on any wired
      # port, and mDNS so `ssh acid.local` works without knowing the lease
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
      };

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
