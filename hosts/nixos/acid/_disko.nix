# The 980 PRO moves to liz; acid's root lands on the 512GB Toshiba that used to
# hold /games. It is a SATA M.2, which the Z370 HD3's single M2A socket supports
# (costing SATA3 0, which acid does not use). acid's whole system is ~180 GiB
# raw, so 512 GB is ample once gaming moves to liz's VM.
{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/ata-TOSHIBA_KSG60ZMV512G_M.2_2280_512GB_882B7015K5TP";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          name = "ACID-ESP";
          type = "EF00";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          name = "ACID-ROOT";
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "acid"
            ];
            subvolumes = {
              "root" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "log" = {
                mountpoint = "/var/log";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "lib" = {
                mountpoint = "/var/lib";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
