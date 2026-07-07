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

        callum

        ssh
        tailscale
        sops

        metrics
        logs

        quadlet-lobehub
        quadlet-onlyboxes
      ]);

      system.stateVersion = "25.11";

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      networking.useNetworkd = true;
      systemd.network.enable = true;
      systemd.network.networks."10-eth" = {
        matchConfig.Name = "eno1";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
}
