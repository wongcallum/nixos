{ lib, ... }:
{
  flake.modules.nixos.samba =
    { pkgs, config, ... }:
    {
      options.modules.samba = {
        shares = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
        };
      };

      config = {
        services.samba = {
          package = pkgs.samba4Full;
          enable = true;
          openFirewall = true;

          # do not forget: # smbpasswd -a username

          settings =
            let
              shares = builtins.mapAttrs (name: path: {
                path = path;
                browseable = true;
                "read only" = false;
                "guest ok" = false;
              }) config.modules.samba.shares;
            in
            {
              global = { };
            }
            // shares;
        };

        services.avahi = {
          enable = true;
          publish.enable = true;
          publish.userServices = true;
          nssmdns4 = true;
          openFirewall = true;
        };

        services.samba-wsdd = {
          enable = true;
          openFirewall = true;
        };
      };
    };

  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.services.samba.enable
          [ "/var/lib/samba" ];
    };
}
