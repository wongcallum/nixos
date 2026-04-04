{
  flake.nixosModules.salt-configuration =
    { lib, config, ... }:
    {
      system.stateVersion = "25.11";
      networking.hostName = "salt";
      boot.loader.systemd-boot.enable = true;

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
