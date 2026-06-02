{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  system.stateVersion = "25.11";

  networking = {
    hostId = "67676767";
    useNetworkd = true;
    nat.externalInterface = "enp1s0";
  };

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "usb_storage"
      "sr_mod"
      "virtio_blk"
      "virtio_scsi"
    ];
    kernelModules = [ "kvm-amd" ];

    # fix rpool import failure on qemu
    zfs.devNodes = "/dev";
  };

  systemd.network = {
    enable = true;
    networks."10-eth" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  services.resolved.settings.Resolve.DNSStubListener = "no";

  modules.gateway.tld = "staging.7sref";
}
