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
                  # recreated at boot by btrfs-rollback
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
                  # Overflow past zram, which fills first at its higher priority.
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
