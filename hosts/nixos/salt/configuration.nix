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
          # start a DHCP Client for IPv4 Addressing/Routing
          DHCP = "ipv4";
          # accept Router Advertisements for Stateless IPv6 Autoconfiguraton (SLAAC)
          IPv6AcceptRA = true;
        };
        # make routing on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };
    };
}
