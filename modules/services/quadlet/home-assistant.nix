{
  flake.modules.nixos.quadlet-home-assistant =
    { config, ... }:
    {
      virtualisation.quadlet.containers.homeassistant = {
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
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "Home Assistant";
        domainName = "hass";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/home-assistant.png";
        addr = "127.0.0.1:8123";
        category = "Home";
      }
    ];
  };
}
