{
  flake.nixosModules.staging-disko = {
    disko.devices = {
      disk = {
        main = {
          device = "/dev/vda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "512M";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "rpool";
                };
              };
            };
          };
        };
      };
      zpool = {
        rpool = {
          type = "zpool";
          options = {
            ashift = "12";
            autotrim = "on";
          };
          rootFsOptions = {
            acltype = "posixacl";
            canmount = "off";
            compression = "zstd";
            dnodesize = "auto";
            normalization = "formD";
            relatime = "on";
            xattr = "sa";
            "com.sun:auto-snapshot" = "false";
          };
          mountpoint = "/";

          datasets = {
            nixos = {
              type = "zfs_fs";
              options.mountpoint = "none";
            };
            "nixos/root" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/";
              postCreateHook = "zfs snapshot rpool/nixos/root@blank";
            };
            "nixos/nix" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/nix";
            };
            "nixos/home" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/home";
            };

            "persist" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/persist";
            };
          };
        };
      };
    };
  };
}
