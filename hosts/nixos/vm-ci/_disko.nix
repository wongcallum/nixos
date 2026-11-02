{ lib, ... }:
{
  # not "main": liz, which installs it, has its own disk-main-ESP label
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
            mountOptions = [ "discard" ];
          };
        };
      };
    };
  };
}
