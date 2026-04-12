{
  flake.nixosModules.staging-configuration =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

      system.stateVersion = "25.11";
      networking.hostId = "67676767";

      boot.initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "usb_storage"
        "sr_mod"
        "virtio_blk"
        "virtio_scsi"
      ];
      boot.kernelModules = [ "kvm-amd" ];

      # fix rpool import failure on qemu
      boot.zfs.devNodes = "/dev";

      networking.useNetworkd = true;
      systemd.network.enable = true;
      systemd.network.networks."10-eth" = {
        matchConfig.Name = "enp1s0";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };

      services.resolved = {
        extraConfig = ''
          DNSStubListener = no
        '';
      };
    };
}
