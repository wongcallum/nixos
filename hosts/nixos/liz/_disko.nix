let
  rootDisk = "nvme-Samsung_SSD_980_PRO_1TB_S5GXNX0T913718H";
  nixDisk = "nvme-Patriot_M.2_P300_128GB_P300ADBB22111800174";

  commonRootFsOptions = {
    acltype = "posixacl";
    canmount = "off";
    compression = "zstd";
    dnodesize = "auto";
    normalization = "formD";
    relatime = "on";
    xattr = "sa";
    "com.sun:auto-snapshot" = "false";
  };
in
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/${rootDisk}";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1G";
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

      nix = {
        device = "/dev/disk/by-id/${nixDisk}";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "npool";
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
        rootFsOptions = commonRootFsOptions;
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
          "nixos/home" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home";
          };

          "persist" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              quota = "200G";
            };
            mountpoint = "/persist";
          };

          # Windows zvols are provisioned separately beneath this dataset.
          "vm" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              quota = "450G";
            };
          };
        };
      };

      npool = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = commonRootFsOptions;

        datasets = {
          nix = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };
        };
      };
    };
  };
}
