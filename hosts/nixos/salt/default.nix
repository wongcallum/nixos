{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.salt = "unstable";

  flake.modules.nixos."hosts/nixos/salt" =
    { config, lib, ... }:
    {
      imports = [
        ./_disko.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        uefi
        zram

        callum

        ssh
        tailscale
        sops

        # metrics
        # logs

        # cottage-witch
      ]);

      system.stateVersion = "25.11";

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "sd_mod"
        ];
        kernelModules = [ "kvm-intel" ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

      networking.useNetworkd = true;
      systemd = {
        network.enable = true;
        network.networks."10-eth" = {
          matchConfig.Name = "eno1";
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };

        # An idle sway session must not suspend the box out from under clients.
        targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
          enable = false;
        });
      };
    };
}
