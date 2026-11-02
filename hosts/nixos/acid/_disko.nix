# macOS owns the GPT, so disko treats each partition as a disk without a
# partition table and finds it by label.
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
