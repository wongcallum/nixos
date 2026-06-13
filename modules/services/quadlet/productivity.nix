let
  networkName = "ai";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-productivity =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "searxng"} 0755 root root -"
        "d ${config.utils.dataDir "open-webui"} 0755 root root -"
        "d ${config.utils.dataDir "silverbullet"} 0755 root root -"
      ];

      modules.containers = {
        ai-searxng = lib.mkDefault true;
        ai-openwebui = lib.mkDefault true;
        silverbullet = lib.mkDefault true;
      };

      virtualisation.quadlet = {
        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.22.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          ai-searxng = lib.mkIf config.modules.containers.ai-searxng (
            config.utils.mkContainer {
              containerConfig = {
                image = "searxng/searxng:latest";
                volumes = [ "${config.utils.dataDir "searxng"}:/etc/searxng:rw" ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.22.0.3";
                dropCapabilities = [ "ALL" ];
                addCapabilities = [
                  "CHOWN"
                  "SETGID"
                  "SETUID"
                  "DAC_OVERRIDE"
                ];
              };
            }
          );

          ai-openwebui = lib.mkIf config.modules.containers.ai-openwebui (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/open-webui/open-webui:main-slim";
                environments = {
                  ENABLE_RAG_WEB_SEARCH = "True";
                  RAG_WEB_SEARCH_ENGINE = "searxng";
                  RAG_WEB_SEARCH_RESULT_COUNT = "3";
                  RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";
                  SEARXNG_QUERY_URL = "http://172.22.0.3:8080/search?q=<query>";
                  WEBUI_AUTH = "False";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.22.0.2";
                publishPorts = [ "8088:8080" ]; # keep here for dad
                volumes = [
                  "${config.utils.dataDir "open-webui"}:/app/backend/data"
                ];
              };
            }
          );

        };
      };

      sops.secrets."docker/silverbullet_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "silverbullet.service" ];
      };

      virtualisation.quadlet.containers.silverbullet = lib.mkIf config.modules.containers.silverbullet (
        config.utils.mkContainer {
          containerConfig = {
            image = "ghcr.io/silverbulletmd/silverbullet:latest";
            notify = "healthy";
            healthStartPeriod = "30s";
            environmentFiles = [ config.sops.secrets."docker/silverbullet_env".path ];
            publishPorts = [ "3000:3000" ];
            volumes = [
              "${config.utils.dataDir "silverbullet"}:/space"
            ];
          };
        }
      );
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services = {
        productivity-openwebui = lib.mkIf config.modules.containers.ai-openwebui {
          name = "OpenWebUI";
          domainName = "chat";
          addr = "172.22.0.2:8080";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/open-webui.png";
          category = "Productivity";
        };

        productivity-silverbullet = lib.mkIf config.modules.containers.silverbullet {
          name = "SilverBullet";
          domainName = "notes";
          addr = "127.0.0.1:3000";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/silverbullet.png";
          category = "Productivity";
        };

        productivity-searxng = lib.mkIf config.modules.containers.ai-searxng {
          name = "SearXNG";
          domainName = "search";
          addr = "172.22.0.3:8080";
          hidden = true;
        };
      };
    };
}
