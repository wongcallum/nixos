{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos."hosts/nixos/milk" =
    { config, lib, ... }:
    {
      imports = [
        ./_disko.nix
        ./_kiosk.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        uefi
        zram

        callum

        ssh
        tailscale
      ]);

      system.stateVersion = "26.05";

      # no sops!!!!
      modules.users.callum.lockPassword = true;

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

      networking.useNetworkd = true;

      networking.wireless.iwd = {
        enable = true;
        settings.General.EnableNetworkConfiguration = false;
      };

      systemd.network = {
        enable = true;
        wait-online.anyInterface = true;
        networks =
          lib.mapAttrs
            (_: match: {
              matchConfig.Name = match;
              networkConfig = {
                DHCP = "ipv4";
                IPv6AcceptRA = true;
              };
              linkConfig.RequiredForOnline = "routable";
            })
            {
              "10-eth" = "en*";
              "20-wifi" = "wl*";
            };
      };
    };
}
