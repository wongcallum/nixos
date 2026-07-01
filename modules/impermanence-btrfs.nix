# https://saylesss88.github.io/installation/unenc/unenc_impermanence.html

{ inputs, ... }:
{
  flake.modules.nixos.impermanence-btrfs =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      boot.initrd.systemd.services.impermanence-root-rollback = {
        description = "Reset the root btrfs subvolume to a fresh state";
        wantedBy = [ "initrd.target" ];
        after = [ "initrd-root-device.target" ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.coreutils
          pkgs.findutils
        ];
        script = ''
          mkdir /btrfs_tmp
          mount ${config.fileSystems."/".device} /btrfs_tmp
          if [[ -e /btrfs_tmp/root ]]; then
            mkdir -p /btrfs_tmp/old_roots
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
            mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
          fi

          delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
          }

          for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
            delete_subvolume_recursively "$i"
          done

          btrfs subvolume create /btrfs_tmp/root
          umount /btrfs_tmp
        '';
      };

      fileSystems."/persist".neededForBoot = true;

      environment.persistence."/persist" = {
        hideMounts = true;
        directories = [
          "/etc"
          "/var/spool"
          "/srv"
          "/root"
        ];
      };
    };
}
