let
  networkName = "collabst";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-collabst =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      tld = config.modules.gateway.tld;
      webUrl = "https://collabst.${tld}";
      minioPublicEndpoint = "storage.collabst.${tld}";
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "collabst/postgres"} 0755 root root -"
        "d ${config.utils.dataDir "collabst/redis"} 0755 root root -"
        "d ${config.utils.dataDir "collabst/minio"} 0755 root root -"
      ];

      modules.containers = {
        collabst = lib.mkDefault true;
      };

      sops.secrets."docker/collabst_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "collabst-backend.service" ];
      };

      virtualisation.quadlet = {
        autoUpdate.enable = true;

        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.26.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          collabst-postgres = lib.mkIf config.modules.containers.collabst (
            config.utils.mkContainer {
              containerConfig = {
                image = "postgres:18";
                environments = {
                  POSTGRES_USER = "postgres";
                  POSTGRES_PASSWORD = "postgres";
                  POSTGRES_DB = "collabst";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.26.0.2";
                volumes = [
                  "${config.utils.dataDir "collabst/postgres"}:/var/lib/postgresql/18/docker"
                ];
                healthCmd = "pg_isready -U postgres -d collabst";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
                healthStartPeriod = "10s";
                notify = "healthy";
              };
            }
          );

          collabst-redis = lib.mkIf config.modules.containers.collabst (
            config.utils.mkContainer {
              containerConfig = {
                image = "redis:7-alpine";
                networks = [ networks.${networkName}.ref ];
                ip = "172.26.0.3";
                volumes = [
                  "${config.utils.dataDir "collabst/redis"}:/data"
                ];
                healthCmd = "redis-cli ping";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
                notify = "healthy";
              };
            }
          );

          collabst-minio = lib.mkIf config.modules.containers.collabst (
            config.utils.mkContainer {
              containerConfig = {
                image = "minio/minio:latest";
                exec = "server /data --console-address :9001";
                environments = {
                  MINIO_ROOT_USER = "minioadmin";
                  MINIO_ROOT_PASSWORD = "minioadmin";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.26.0.4";
                volumes = [
                  "${config.utils.dataDir "collabst/minio"}:/data"
                ];
                healthCmd = "curl -f http://localhost:9000/minio/health/live";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
                notify = "healthy";
              };
            }
          );

          collabst-backend = lib.mkIf config.modules.containers.collabst (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/collabst/collabst:latest";
                autoUpdate = "registry";
                environmentFiles = [ config.sops.secrets."docker/collabst_env".path ];
                environments = {
                  DATABASE_URL = "postgresql+asyncpg://postgres:postgres@172.26.0.2:5432/collabst";
                  REDIS_URL = "redis://172.26.0.3:6379/0";
                  MINIO_ENDPOINT = "172.26.0.4:9000";
                  MINIO_PUBLIC_ENDPOINT = minioPublicEndpoint;
                  MINIO_ACCESS_KEY = "minioadmin";
                  MINIO_SECRET_KEY = "minioadmin";
                  MINIO_SECURE = "false";
                  MINIO_PUBLIC_SECURE = "true";
                  MINIO_BUCKET_NAME = "collabst";
                  ALGORITHM = "HS256";
                  WEB_URL = webUrl;
                  API_V1_STR = "/api/v1";
                  CORS_ORIGINS = webUrl;
                  REGISTRATION_ENABLED = "false";
                  ENVIRONMENT = "production";
                  FRONTEND_DIST_DIR = "/app/frontend-dist";
                  UVICORN_WORKERS = "4";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.26.0.5";
              };
              unitConfig = {
                Requires = [
                  "collabst-postgres.service"
                  "collabst-redis.service"
                  "collabst-minio.service"
                ];
                After = [
                  "collabst-postgres.service"
                  "collabst-redis.service"
                  "collabst-minio.service"
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
      modules.gateway.services = {
        collabst = lib.mkIf config.modules.containers.collabst {
          name = "Collabst";
          domainName = "collabst";
          addr = "172.26.0.5:8000";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/typst.png";
          category = "Productivity";
        };

        collabst-storage = lib.mkIf config.modules.containers.collabst {
          name = "Collabst Storage";
          domainName = "storage.collabst";
          addr = "172.26.0.4:9000";
          hidden = true;
        };
      };
    };
}
