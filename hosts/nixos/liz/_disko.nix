# Two pools, split by how much their contents are worth.
#
#   rpool (Samsung 980 PRO 1TB) — boot chain, system, service state, VM volumes.
#   npool (Patriot P300 128GB)  — /nix, and nothing else.
#
# The Patriot is the older, DRAM-less drive and is expected to fail first, so it
# carries only derived state. See the migration plan for the capacity budget.
let
  # The 980 PRO carries everything whose loss would cost something: the boot
  # chain, the system, service state and (later) the VM volumes.
  rootDisk = "nvme-Samsung_SSD_980_PRO_1TB_S5GXNX0T913718H";

  # The Patriot is DRAM-less and old, so it gets only /nix — the most
  # write-heavy and most reconstructible thing on the box. Losing it costs a
  # reinstall, not data. The ESP deliberately lives on the 980 PRO instead, so a
  # dead Patriot is a failed mount rather than a machine that won't boot at all.
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
            # 1G, not the old 512M: that one was already 42% full with a single
            # generation's kernels on it.
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

          # Quotas are what stop the VM volumes and the homelab from eating each
          # other: this is a single non-redundant drive holding both.
          "persist" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              quota = "200G";
            };
            mountpoint = "/persist";
          };

          # Container only. The Windows guest's zvols get created by hand when the
          # VM is actually built — sizing and volblocksize are decisions better
          # made then than baked into the install.
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
