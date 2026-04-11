{
  flake.modules.nixos.impermanence-zfs =
    let
      zfsPool = "rpool";
      zfsRootDataset = "nixos/root";
      zfsSnapshot = "blank";
    in
    { pkgs, ... }:
    {
      console.earlySetup = true;
      systemd.services.systemd-vconsole-setup.unitConfig.After = "local-fs.target";

      boot.initrd.systemd = {
        enable = true;
        services.initrd-rollback-root = {
          after = [ "zfs-import-${zfsPool}.service" ];
          wantedBy = [ "initrd.target" ];
          before = [ "sysroot.mount" ];
          path = [ pkgs.zfs ];
          description = "Rollback root filesystem";
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = "zfs rollback -r ${zfsPool}/${zfsRootDataset}@${zfsSnapshot}";
        };
      };
    };
}
