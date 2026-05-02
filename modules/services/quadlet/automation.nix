{
  flake.modules.nixos.quadlet-automation =
    { config, ... }:
    {
      virtualisation.quadlet.containers = {
        homeassistant = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "ghcr.io/home-assistant/home-assistant:stable";
            podmanArgs = [
              "--privileged"
              "--network=host"
            ];
            volumes = [
              "${config.utils.dataDir "home-assistant"}:/config"
              "/etc/localtime:/etc/localtime:ro"
              "/run/dbus:/run/dbus:ro"
            ];
          };
        };

        evcc = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "evcc/evcc:latest";
            volumes = [
              "${config.users.users.colin.home}/evcc:/root/.evcc"
              "${config.users.users.colin.home}/evcc.yaml:/etc/evcc.yaml"
            ];
            publishPorts = [
              "7070:7070"
              "8887:8887"
            ];
          };
        };

        mongo = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "mongo:latest";
            environments = {
              MONGO_INITDB_ROOT_USERNAME = "admin";
              MONGO_INITDB_ROOT_PASSWORD = "secretpassword";
            };
            volumes = [ "${config.users.users.colin.home}/mongo_data:/data/db" ];
            publishPorts = [ "27017:27017" ];
          };
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.localServices = lib.mkMerge [
        (lib.optional (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "homeassistant" ] config)
          {
            name = "Home Assistant";
            domainName = "hass";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/home-assistant.png";
            addr = "127.0.0.1:8123";
            category = "Automation";
          }
        )
        (lib.optional (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "evcc" ] config) {
          name = "evcc";
          domainName = "evcc";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/evcc.png";
          addr = "127.0.0.1:7070";
          category = "Automation";
        })
      ];
    };
}
