let
  networkName = "lobehub";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-lobehub =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      tld = config.modules.gateway.tld;
      appUrl = "https://lobehub.${tld}";
      s3PublicDomain = "https://lobehub-storage.${tld}";
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "lobehub/db"} 0755 root root -"
        "d ${config.utils.dataDir "lobehub/redis"} 0755 999 999 -"
        "d ${config.utils.dataDir "lobehub/minio"} 0755 root root -"
      ];

      modules.containers = {
        lobehub = lib.mkDefault true;
      };

      sops.secrets."docker/lobehub_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "lobehub.service" ];
      };

      virtualisation.quadlet = {
        autoUpdate.enable = true;

        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.28.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          lobehub-postgres = lib.mkIf config.modules.containers.lobehub (
            config.utils.mkContainer {
              containerConfig = {
                image = "paradedb/paradedb:latest-pg17";
                environments = {
                  POSTGRES_USER = "postgres";
                  POSTGRES_PASSWORD = "postgres";
                  POSTGRES_DB = "lobechat";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.28.0.2";
                volumes = [
                  "${config.utils.dataDir "lobehub/db"}:/var/lib/postgresql/data"
                ];
                healthCmd = "pg_isready -U postgres -d lobechat";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
                healthStartPeriod = "10s";
                notify = "healthy";
              };
            }
          );

          lobehub-redis = lib.mkIf config.modules.containers.lobehub (
            config.utils.mkContainer {
              containerConfig = {
                image = "redis:7-alpine";
                networks = [ networks.${networkName}.ref ];
                ip = "172.28.0.3";
                volumes = [
                  "${config.utils.dataDir "lobehub/redis"}:/data"
                ];
                healthCmd = "redis-cli ping";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
                notify = "healthy";
              };
            }
          );

          lobehub-minio = lib.mkIf config.modules.containers.lobehub (
            config.utils.mkContainer {
              containerConfig = {
                image = "minio/minio:latest";
                exec = "server /data --console-address :9001";
                environments = {
                  MINIO_ROOT_USER = "minioadmin";
                  MINIO_ROOT_PASSWORD = "minioadmin";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.28.0.4";
                publishPorts = [ "9000:9000" ];
                volumes = [
                  "${config.utils.dataDir "lobehub/minio"}:/data"
                ];
                healthCmd = "curl -f http://localhost:9000/minio/health/live";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
                notify = "healthy";
              };
            }
          );

          # one-shot: create the `lobe` bucket and allow anonymous downloads so
          # browser file URLs (via lobehub-storage.${tld}) resolve.
          lobehub-minio-init = lib.mkIf config.modules.containers.lobehub {
            containerConfig = {
              image = "minio/mc:latest";
              entrypoint = "/bin/sh";
              exec = "-c 'mc alias set local http://172.28.0.4:9000 minioadmin minioadmin && mc mb --ignore-existing local/lobe && mc anonymous set download local/lobe'";
              networks = [ networks.${networkName}.ref ];
            };
            unitConfig = {
              Requires = [ "lobehub-minio.service" ];
              After = [ "lobehub-minio.service" ];
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = "yes";
              Restart = "no";
            };
          };

          lobehub = lib.mkIf config.modules.containers.lobehub (
            config.utils.mkContainer {
              containerConfig = {
                image = "docker.io/lobehub/lobehub:latest";
                autoUpdate = "registry";
                publishPorts = [ "3210:3210" ];
                environmentFiles = [ config.sops.secrets."docker/lobehub_env".path ];
                environments = {
                  DATABASE_URL = "postgresql://postgres:postgres@172.28.0.2:5432/lobechat";
                  APP_URL = appUrl;
                  INTERNAL_APP_URL = "http://localhost:3210";
                  REDIS_URL = "redis://172.28.0.3:6379";
                  REDIS_PREFIX = "lobechat";
                  REDIS_TLS = "0";
                  S3_ENDPOINT = "http://172.28.0.4:9000";
                  S3_PUBLIC_DOMAIN = s3PublicDomain;
                  S3_BUCKET = "lobe";
                  S3_ENABLE_PATH_STYLE = "1";
                  S3_SET_ACL = "0";
                  S3_ACCESS_KEY_ID = "minioadmin";
                  S3_SECRET_ACCESS_KEY = "minioadmin";
                  LLM_VISION_IMAGE_USE_BASE64 = "1";

                  # self-hosted OnlyBoxes sandbox (see ./onlyboxes.nix). The
                  # console shares the lobehub network at 172.28.0.6. The
                  # matching ONLYBOXES_JIT_SIGNING_KEY lives in the sops env file.
                  SANDBOX_PROVIDER = "onlyboxes";
                  ONLYBOXES_BASE_URL = "http://172.28.0.6:8089";

                  # api keys defined in nixos-secrets
                  SEARCH_PROVIDERS = "tavily,exa";
                  CRAWLER_IMPLS = "exa,naive";
                  #TAVILY_EXTRACT_DEPTH = "advanced";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.28.0.5";
              };
              unitConfig = {
                Requires = [
                  "lobehub-postgres.service"
                  "lobehub-redis.service"
                  "lobehub-minio.service"
                  "lobehub-minio-init.service"
                ];
                After = [
                  "lobehub-postgres.service"
                  "lobehub-redis.service"
                  "lobehub-minio.service"
                  "lobehub-minio-init.service"
                ];
              };
            }
          );
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, ... }:
    {
      modules.gateway.services = {
        lobehub = {
          name = "LobeChat";
          domainName = "lobehub";
          addr = "${config.modules.hostAddrs.salt}:3210";
          iconUrl = "https://cdn.jsdelivr.net/npm/@lobehub/icons-static-svg@latest/icons/lobehub-color.svg";
          category = "Productivity";
        };

        lobehub-storage = {
          name = "LobeChat Storage";
          domainName = "lobehub-storage";
          addr = "${config.modules.hostAddrs.salt}:9000";
          hidden = true;
        };
      };
    };
}
