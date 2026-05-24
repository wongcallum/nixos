let
  networkName = "gallery";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-gallery =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "gallery-db"} 0755 root root -"
      ];

      modules.containers = {
        gallery = lib.mkDefault true;
      };

      sops.secrets."docker/gallery_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "gallery-app.service" ];
      };

      virtualisation.quadlet = {
        autoUpdate.enable = true;

        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.24.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          gallery-db = lib.mkIf config.modules.containers.gallery (
            config.utils.mkContainer {
              containerConfig = {
                image = "postgres:18-alpine";
                environments = {
                  POSTGRES_USER = "postgres";
                  POSTGRES_PASSWORD = "postgres";
                  POSTGRES_DB = "gallery";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.24.0.2";
                volumes = [
                  "${config.utils.dataDir "gallery-db"}:/var/lib/postgresql"
                ];
                healthCmd = "pg_isready -U postgres -d gallery";
                healthInterval = "5s";
                healthTimeout = "5s";
                healthRetries = 5;
                healthStartPeriod = "10s";
                notify = "healthy";
              };
            }
          );

          gallery-app = lib.mkIf config.modules.containers.gallery {
            containerConfig = {
              image = "ghcr.io/wongcallum/gallery.callumwong.com:master";
              autoUpdate = "registry";
              environmentFiles = [ config.sops.secrets."docker/gallery_env".path ];
              environments = {
                DATABASE_URL = "postgresql://postgres:postgres@172.24.0.2:5432/gallery";
              };
              networks = [ networks.${networkName}.ref ];
              ip = "172.24.0.4";
            };
            unitConfig = {
              Requires = [
                "gallery-db.service"
              ];
              After = [
                "gallery-db.service"
              ];
            };
            serviceConfig = {
              Restart = "always";
              RestartSec = "10";
            };
          };
        };
      };
    };
}
