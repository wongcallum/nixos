{ lib, ... }:
{
  flake.modules.nixos.autofs =
    { config, pkgs, ... }:
    lib.mkIf config.modules.tailscale.enable (
      let
        shares = {
          callum = "/media/callum";
          media = "/media/media";
        };

        mountOpts = "soft,uid=callum,gid=users,file_mode=0700,dir_mode=0700,vers=3.0,credentials=/etc/samba/callum";

        autoLiz = pkgs.writeText "auto.liz" (
          lib.concatLines (
            lib.mapAttrsToList (
              share: mountPoint:
              "${mountPoint} -fstype=cifs,${mountOpts} ://${config.modules.hostAddrs.liz}/${share}"
            ) shares
          )
        );
      in
      {
        environment.systemPackages = [ pkgs.cifs-utils ];
        systemd.services.autofs.path = [ pkgs.cifs-utils ];

        systemd.tmpfiles.rules = map (dir: "d ${dir} 0755 root root -") (
          lib.unique (map dirOf (lib.attrValues shares))
        );

        services.autofs = {
          enable = true;

          autoMaster = ''
            /- file:${autoLiz} --negative-timeout=60
          '';
        };
      }
    );
}
