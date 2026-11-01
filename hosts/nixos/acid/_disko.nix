# Dual-boot with macOS (OpenCore). The disk's GPT, OpenCore's ESP and the APFS
# container belong to macOS, so disko only describes the two partitions that
# macOS carved out for acid, each as a whole "disk" without a partition table.
# They are addressed by filesystem label, which only exists once formatted, so
# disko never matches a partition that holds something else.
{
  disko.devices.disk = {
    esp = {
      device = "/dev/disk/by-label/ACID-ESP";
      type = "disk";
      content = {
        type = "filesystem";
        format = "vfat";
        extraArgs = [
          "-n"
          "ACID-ESP"
        ];
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
    };

    root = {
      device = "/dev/disk/by-label/acid";
      type = "disk";
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
}
