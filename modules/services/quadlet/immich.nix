let
  networkName = "immich";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-immich =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      options.modules.immich = {
        externalLibraries = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "External libraries to mount into immich (at /external/{key})";
        };
      };

      config = {
        systemd.tmpfiles.rules = [
          "d ${config.utils.dataDir "immich/db"} 0755 root root -"
          "d ${config.utils.dataDir "immich/model-cache"} 0755 root root -"
          "d ${config.utils.dataDir "immich/data"} 0755 root root -"
          "d ${config.utils.dataDir "immich/immich-stack/logs"} 0755 root root -"
        ];

        modules.containers = {
          immich = lib.mkDefault true;
        };

        sops.secrets."docker/immich-stack_env" = {
          owner = "root";
          group = "root";
          mode = "0440";
          restartUnits = [ "immich-stack.service" ];
        };

        virtualisation.quadlet = {
          autoUpdate.enable = true;

          networks.${networkName} = {
            networkConfig = {
              subnets = [ "172.25.0.0/16" ];
              disableDns = true;
            };
          };

          containers = {
            immich-db = lib.mkIf config.modules.containers.immich (
              config.utils.mkContainer {
                containerConfig = {
                  image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
                  environments = {
                    POSTGRES_USER = "postgres";
                    POSTGRES_PASSWORD = "postgres";
                    POSTGRES_DB = "immich";
                    POSTGRES_INITDB_ARGS = "--data-checksums";
                  };
                  shmSize = "128m";
                  networks = [ networks.${networkName}.ref ];
                  ip = "172.25.0.2";
                  volumes = [
                    "${config.utils.dataDir "immich/db"}:/var/lib/postgresql/data"
                  ];
                  healthCmd = "pg_isready -U postgres -d immich";
                  healthInterval = "5s";
                  healthTimeout = "5s";
                  healthRetries = 5;
                  healthStartPeriod = "10s";
                  notify = "healthy";
                };
              }
            );

            immich-redis = lib.mkIf config.modules.containers.immich (
              config.utils.mkContainer {
                containerConfig = {
                  image = "docker.io/valkey/valkey:9@sha256:3b55fbaa0cd93cf0d9d961f405e4dfcc70efe325e2d84da207a0a8e6d8fde4f9";
                  networks = [ networks.${networkName}.ref ];
                  ip = "172.25.0.3";
                  healthCmd = "redis-cli ping";
                  healthInterval = "5s";
                  healthTimeout = "5s";
                  healthRetries = 5;
                  notify = "healthy";
                };
              }
            );

            immich-ml = lib.mkIf config.modules.containers.immich (
              config.utils.mkContainer {
                containerConfig = {
                  image = "ghcr.io/immich-app/immich-machine-learning:release";
                  networks = [ networks.${networkName}.ref ];
                  ip = "172.25.0.4";
                  volumes = [
                    "${config.utils.dataDir "immich/model-cache"}:/cache"
                  ];
                };
              }
            );

            immich-server = lib.mkIf config.modules.containers.immich (
              config.utils.mkContainer {
                containerConfig = {
                  image = "ghcr.io/immich-app/immich-server:release";
                  environments = {
                    DB_HOSTNAME = "172.25.0.2";
                    DB_USERNAME = "postgres";
                    DB_PASSWORD = "postgres";
                    DB_DATABASE_NAME = "immich";
                    REDIS_HOSTNAME = "172.25.0.3";
                    IMMICH_MACHINE_LEARNING_URL = "http://172.25.0.4:3003";
                  };
                  networks = [ networks.${networkName}.ref ];
                  ip = "172.25.0.5";
                  volumes =
                    lib.mapAttrsToList (
                      name: path: "${path}:/external/${name}:ro"
                    ) config.modules.immich.externalLibraries
                    ++ [
                      "${config.utils.dataDir "immich/data"}:/data"
                      "/etc/localtime:/etc/localtime:ro"
                    ];
                };
                unitConfig = {
                  Requires = [
                    "immich-db.service"
                    "immich-redis.service"
                  ];
                  After = [
                    "immich-db.service"
                    "immich-redis.service"
                    "immich-ml.service"
                  ];
                };
              }
            );

            immich-stack = config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/majorfi/immich-stack:latest";
                autoUpdate = "registry";
                environmentFiles = [ config.sops.secrets."docker/immich-stack_env".path ];
                environments = {
                  API_URL = "http://172.25.0.5:2283/api";
                  RUN_MODE = "cron";
                  CRON_INTERVAL = "3600";
                  LOG_LEVEL = "info";
                  LOG_FORMAT = "text";
                  LOG_FILE = "/app/logs/immich-stack.log";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.25.0.6";
                volumes = [
                  "${config.utils.dataDir "immich/immich-stack/logs"}:/app/logs"
                ];
              };
              unitConfig = {
                Requires = [ "immich-server.service" ];
                After = [ "immich-server.service" ];
              };
            };
          };
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services = {
        immich = lib.mkIf config.modules.containers.immich {
          name = "Immich";
          domainName = "photos";
          addr = "172.25.0.5:2283";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/immich.png";
          category = "Media";
        };
      };
    };
}
