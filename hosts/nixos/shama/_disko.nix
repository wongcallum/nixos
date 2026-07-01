{
  disko.devices.disk = {
    esp = {
      device = "/dev/disk/by-partlabel/SHAMA-ESP";
      type = "disk";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
    };

    root = {
      device = "/dev/disk/by-partlabel/SHAMA-ROOT";
      type = "disk";
      content = {
        type = "btrfs";
        extraArgs = [
          "-f"
          "-L"
          "shama"
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
