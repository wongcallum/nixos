{ lib, ... }:
{
  flake.modules.nixos.samba =
    { pkgs, config, ... }:
    {
      options.modules.samba = {
        shares = lib.mkOption {
          default = { };
          description = ''
            SMB shares, keyed by share name. A bare string is shorthand for
            `{ path = <string>; }`, which is all most shares need.
          '';
          type = lib.types.attrsOf (
            lib.types.coercedTo lib.types.str (path: { inherit path; }) (
              lib.types.submodule {
                options = {
                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "Filesystem path exported by the share.";
                  };

                  readOnly = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Export the share read-only.";
                  };
                };
              }
            )
          );
        };
      };

      config = {
        modules.samba.enable = lib.mkDefault true;

        services = {
          samba = {
            package = pkgs.samba4Full;
            enable = true;
            openFirewall = true;

            # do not forget: # smbpasswd -a username

            settings =
              let
                shares = builtins.mapAttrs (_: share: {
                  inherit (share) path;
                  browseable = true;
                  "read only" = share.readOnly;
                  "guest ok" = false;
                  "follow symlinks" = true;
                  "wide links" = true;
                }) config.modules.samba.shares;
              in
              {
                global = {
                  "allow insecure wide links" = true;
                };
              }
              // shares;
          };

          avahi = {
            enable = true;
            publish.enable = true;
            publish.userServices = true;
            nssmdns4 = true;
            openFirewall = true;
          };

          samba-wsdd = {
            enable = true;
            openFirewall = true;
          };
        };
      };
    };

  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.modules.samba.enable
          [ "/var/lib/samba" ];
    };
}
