let
  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/ata-APPLE_SSD_SM0512G_S1W3NYAG914149";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "crypted";
            # Read only while formatting; nixos-anywhere uploads it.
            passwordFile = "/tmp/secret.key";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-L"
                "wky"
              ];
              subvolumes = {
                "root" = {
                  mountpoint = "/";
                  mountOptions = btrfsOpts;
                };
                "home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsOpts;
                };
                "nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOpts;
                };
                "persist" = {
                  mountpoint = "/persist";
                  mountOptions = btrfsOpts;
                };
                "log" = {
                  mountpoint = "/var/log";
                  mountOptions = btrfsOpts;
                };
                "lib" = {
                  mountpoint = "/var/lib";
                  mountOptions = btrfsOpts;
                };
              };
            };
          };
        };
      };
    };
  };
}
