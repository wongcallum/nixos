let
  networkName = "ai";
in
{
  flake.modules.nixos.quadlet-ai =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      virtualisation.quadlet = {
        networks.${networkName}.networkConfig = {
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
            networks = [ networks.${networkName}.ref ];
            ip = "172.22.0.2";
            publishPorts = [ "8088:8080" ];
            volumes = [
              "${config.utils.dataDir "open-webui"}:/app/backend/data"
            ];
          };
        };
      };
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "OpenWebUI";
        domainName = "openwebui";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/open-webui.png";
        addr = "172.22.0.2:8080";
        category = "Productivity";
      }
      {
        name = "SearXNG";
        domainName = "searx";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/searxng.png";
        addr = "172.22.0.3:8080";
        hidden = true;
      }
    ];
  };
}
