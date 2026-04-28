{
  flake.modules.nixos.quadlet-productivity =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      virtualisation.quadlet = {
        networks.openwebui.networkConfig = {
          subnets = [ "172.22.0.0/16" ];
          disableDns = true;
        };

        containers.ai-searxng = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "searxng/searxng:latest";
            volumes = [ "${config.utils.dataDir "searxng"}:/etc/searxng:rw" ];
            networks = [ networks.openwebui.ref ];
            ip = "172.22.0.3";
            dropCapabilities = [ "ALL" ];
            addCapabilities = [
              "CHOWN"
              "SETGID"
              "SETUID"
              "DAC_OVERRIDE"
            ];
          };
        };

        containers.ai-openwebui = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
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
            networks = [ networks.openwebui.ref ];
            ip = "172.22.0.2";
            publishPorts = [ "8088:8080" ];
            volumes = [
              "${config.utils.dataDir "open-webui"}:/app/backend/data"
            ];
          };
        };
      };

      sops.secrets."docker/silverbullet_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
      };

      virtualisation.quadlet.containers.silverbullet = {
        serviceConfig = {
          Restart = "always";
          RestartSec = "10";
        };
        containerConfig = {
          image = "ghcr.io/silverbulletmd/silverbullet:latest";
          environmentFiles = [ config.sops.secrets."docker/silverbullet_env".path ];
          publishPorts = [ "3000:3000" ];
          volumes = [
            "${config.utils.dataDir "silverbullet"}:/space"
          ];
        };
      };
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "OpenWebUI";
        domainName = "chat";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/open-webui.png";
        addr = "172.22.0.2:8080";
        category = "Productivity";
      }
      {
        name = "SilverBullet";
        domainName = "notes";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/silverbullet.png";
        addr = "127.0.0.1:3000";
        category = "Productivity";
      }
      {
        name = "SearXNG";
        domainName = "search";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/searxng.png";
        addr = "172.22.0.3:8080";
        hidden = true;
      }
    ];
  };
}
