{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  # coder moved here from unstable vm-coder, and its database must only
  # migrate forward.
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

        coder

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

      # Overflow for workspace builds past zram, which fills first at its
      # higher priority.
      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 16 * 1024;
        }
      ];

      networking.useNetworkd = true;
      systemd = {
        network = {
          enable = true;
          # Off unless coder is in use; liz wakes it with a magic packet.
          # networking.interfaces.<name>.wakeOnLan matches the kernel's eth0
          # rather than eno1, so match the NIC itself and keep 99-default's
          # naming, which a matching .link file replaces.
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

        # Workspaces must stay reachable while salt is on.
        targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
          enable = false;
        });
      };
    };
}
