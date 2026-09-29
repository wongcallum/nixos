let
  networkName = "lobehub";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-lobehub =
    { config, pkgs, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      tld = config.modules.gateway.tld;
      appUrl = "https://lobehub.${tld}";
      s3PublicDomain = "https://lobehub-storage.${tld}";
      s3AccessKey = "rustfsadmin";
      s3SecretKey = "rustfsadmin";

      # mirrors docker-compose/deploy/bucket.config.json upstream
      bucketPolicy = pkgs.writeText "lobehub-bucket-policy.json" (
        builtins.toJSON {
          Version = "2012-10-17";
          Statement = [
            {
              Effect = "Allow";
              Principal.AWS = [ "*" ];
              Action = [ "s3:GetObject" ];
              Resource = [ "arn:aws:s3:::lobe/*" ];
            }
          ];
        }
      );
      bucketCors = pkgs.writeText "lobehub-bucket-cors.xml" "<CORSConfiguration><CORSRule><AllowedOrigin>*</AllowedOrigin><AllowedMethod>GET</AllowedMethod><AllowedMethod>PUT</AllowedMethod><AllowedMethod>HEAD</AllowedMethod><AllowedHeader>*</AllowedHeader><ExposeHeader>ETag</ExposeHeader><MaxAgeSeconds>3600</MaxAgeSeconds></CORSRule></CORSConfiguration>";
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "lobehub/db"} 0755 root root -"
        "d ${config.utils.dataDir "lobehub/redis"} 0755 999 999 -"
        "d ${config.utils.dataDir "lobehub/rustfs"} 0755 10001 10001 -"
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

          lobehub-rustfs = lib.mkIf config.modules.containers.lobehub (
            config.utils.mkContainer {
              containerConfig = {
                image = "docker.io/rustfs/rustfs:latest";
                environments = {
                  RUSTFS_ACCESS_KEY = s3AccessKey;
                  RUSTFS_SECRET_KEY = s3SecretKey;
                  RUSTFS_CONSOLE_ENABLE = "true";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.28.0.4";
                publishPorts = [ "9000:9000" ];
                volumes = [
                  "${config.utils.dataDir "lobehub/rustfs"}:/data"
                ];
                healthCmd = "wget -qO- http://localhost:9000/health";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 30;
                notify = "healthy";
              };
            }
          );

          # one-shot: create the `lobe` bucket, allow anonymous downloads so
          # browser file URLs (via lobehub-storage.${tld}) resolve, and add the
          # CORS rule browsers need for presigned uploads.
          lobehub-rustfs-init = lib.mkIf config.modules.containers.lobehub {
            containerConfig = {
              image = "docker.io/rustfs/rc:latest";
              entrypoint = "/bin/sh";
              exec = "-c 'set -eu; rc alias set local http://172.28.0.4:9000 ${s3AccessKey} ${s3SecretKey}; rc mb local/lobe --ignore-existing; rc anonymous set-json /bucket.config.json local/lobe; rc bucket cors set local/lobe /cors.xml'";
              networks = [ networks.${networkName}.ref ];
              volumes = [
                "${bucketPolicy}:/bucket.config.json:ro"
                "${bucketCors}:/cors.xml:ro"
              ];
            };
            unitConfig = {
              Requires = [ "lobehub-rustfs.service" ];
              After = [ "lobehub-rustfs.service" ];
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
                  S3_ACCESS_KEY_ID = s3AccessKey;
                  S3_SECRET_ACCESS_KEY = s3SecretKey;
                  LLM_VISION_IMAGE_USE_BASE64 = "1";

                  # allow login from LobeHub Desktop app
                  ENABLE_OIDC = "1";

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
                  "lobehub-rustfs.service"
                  "lobehub-rustfs-init.service"
                ];
                After = [
                  "lobehub-postgres.service"
                  "lobehub-redis.service"
                  "lobehub-rustfs.service"
                  "lobehub-rustfs-init.service"
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
          addr = "${config.modules.hostAddrs.liz}:3210";
          iconUrl = "https://cdn.jsdelivr.net/npm/@lobehub/icons-static-svg@latest/icons/lobehub-color.svg";
          category = "Productivity";
        };

        lobehub-storage = {
          name = "LobeChat Storage";
          domainName = "lobehub-storage";
          addr = "${config.modules.hostAddrs.liz}:9000";
          hidden = true;
        };
      };
    };
}
