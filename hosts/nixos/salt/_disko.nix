{ lib, ... }:
let
  mountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices = {
    disk = {
      main = {
        device = lib.mkDefault "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  # btrfs-rollback recreates this at boot.
                  "root" = {
                    mountpoint = "/";
                    inherit mountOptions;
                  };
                  "home" = {
                    mountpoint = "/home";
                    inherit mountOptions;
                  };
                  "nix" = {
                    mountpoint = "/nix";
                    inherit mountOptions;
                  };
                  "persist" = {
                    mountpoint = "/persist";
                    inherit mountOptions;
                  };
                  # Takes the overflow once zram fills.
                  "swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "16G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
