let
  networkName = "new-api";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-new-api =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      dataDir = config.utils.dataDir "new-api";
      envFile = config.sops.secrets."docker/new-api_env".path;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${dataDir}/data 0755 root root -"
        "d ${dataDir}/logs 0755 root root -"
        "d ${dataDir}/postgres 0700 999 999 -"
      ];

      modules.containers.new-api = lib.mkDefault true;

      sops.secrets."docker/new-api_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [
          "new-api.service"
          "new-api-postgres.service"
        ];
      };

      virtualisation.quadlet = {
        autoUpdate.enable = true;

        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.29.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          new-api-postgres = lib.mkIf config.modules.containers.new-api (
            config.utils.mkContainer {
              containerConfig = {
                image = "postgres:15-alpine";
                environmentFiles = [ envFile ];
                environments = {
                  POSTGRES_USER = "new-api";
                  POSTGRES_DB = "new-api";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.29.0.2";
                volumes = [ "${dataDir}/postgres:/var/lib/postgresql/data" ];
                healthCmd = "pg_isready -U new-api -d new-api";
                healthInterval = "5s";
                healthTimeout = "5s";
                healthRetries = 5;
                healthStartPeriod = "10s";
                notify = "healthy";
              };
            }
          );

          new-api-redis = lib.mkIf config.modules.containers.new-api (
            config.utils.mkContainer {
              containerConfig = {
                image = "redis:7-alpine";
                networks = [ networks.${networkName}.ref ];
                ip = "172.29.0.3";
                healthCmd = "redis-cli ping";
                healthInterval = "5s";
                healthTimeout = "5s";
                healthRetries = 5;
                healthStartPeriod = "5s";
                notify = "healthy";
              };
            }
          );

          new-api = lib.mkIf config.modules.containers.new-api (
            config.utils.mkContainer {
              containerConfig = {
                image = "docker.io/calciumion/new-api:latest";
                autoUpdate = "registry";
                exec = "--log-dir /app/logs";
                environmentFiles = [ envFile ];
                environments = {
                  REDIS_CONN_STRING = "redis://172.29.0.3:6379";
                  ERROR_LOG_ENABLED = "true";
                  BATCH_UPDATE_ENABLED = "true";
                  NODE_NAME = "new-api-liz";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.29.0.4";
                volumes = [
                  "${dataDir}/data:/data"
                  "${dataDir}/logs:/app/logs"
                ];
                healthCmd = "wget -q -O - http://localhost:3000/api/status | grep -o '\"success\":\\s*true' || exit 1";
                healthInterval = "30s";
                healthTimeout = "10s";
                healthRetries = 3;
                healthStartPeriod = "30s";
              };
              unitConfig = {
                Requires = [
                  "new-api-postgres.service"
                  "new-api-redis.service"
                ];
                After = [
                  "new-api-postgres.service"
                  "new-api-redis.service"
                ];
              };
            }
          );
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.new-api = lib.mkIf config.modules.containers.new-api {
        name = "New API";
        domainName = "new-api";
        addr = "172.29.0.4:3000";
        iconUrl = "https://raw.githubusercontent.com/QuantumNous/new-api/main/web/public/logo.png";
        category = "Productivity";
      };
    };
}
