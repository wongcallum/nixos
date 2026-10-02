{ lib, ... }:
{
  # Not "main": partitions are found by label, and liz, which installs and
  # inspects this disk, has its own disk-main-ESP.
  disko.devices.disk.ci = {
    # liz's QEMU unit gives the disk this serial; disko-install overrides it
    device = lib.mkDefault "/dev/disk/by-id/virtio-ci";
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
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            # hands space freed by nix GC back to the sparse zvol
            mountOptions = [ "discard" ];
          };
        };
      };
    };
  };
}
