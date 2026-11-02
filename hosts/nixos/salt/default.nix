{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
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

        btrfs-rollback
        persistence

        callum

        ssh
        tailscale
        sops
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
        network = {
          enable = true;
          # wakeOnLan would match the kernel's eth0; a .link replaces 99-default's naming
          links."40-eno1" = {
            matchConfig.PermanentMACAddress = "54:bf:64:8f:34:e8";
            linkConfig = {
              NamePolicy = "keep kernel database onboard slot path";
              AlternativeNamesPolicy = "database onboard slot path mac";
              MACAddressPolicy = "persistent";
              WakeOnLan = "magic";
            };
          };
          networks."10-eth" = {
            matchConfig.Name = "eno1";
            networkConfig = {
              DHCP = "ipv4";
              IPv6AcceptRA = true;
            };
            linkConfig.RequiredForOnline = "routable";
          };
        };

        targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
          enable = false;
        });
      };
    };
}
