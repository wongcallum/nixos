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
      };
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "Home Assistant";
        domainName = "hass";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/home-assistant.png";
        addr = "127.0.0.1:8123";
        category = "Automation";
      }
      {
        name = "evcc";
        domainName = "evcc";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/evcc.png";
        addr = "127.0.0.1:7070";
        category = "Automation";
      }
    ];
  };
}
