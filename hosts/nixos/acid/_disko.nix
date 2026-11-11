let
  mountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/ata-TOSHIBA_KSG60ZMV512G_M.2_2280_512GB_882B7015K5TP";
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
        root = {
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
              "log" = {
                mountpoint = "/var/log";
                inherit mountOptions;
              };
              "lib" = {
                mountpoint = "/var/lib";
                inherit mountOptions;
              };
            };
          };
        };
      };
    };
  };
}
