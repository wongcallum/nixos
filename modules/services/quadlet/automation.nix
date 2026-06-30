{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-automation =
    { config, ... }:
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "home-assistant"} 0755 root root -"
        "d ${config.users.users.colin.home}/evcc 0755 colin users -"
        "d ${config.users.users.colin.home}/mongo_data 0755 colin users -"
      ];

      modules.containers = {
        homeassistant = lib.mkDefault true;
        evcc = lib.mkDefault true;
        mongo = lib.mkDefault true;
      };

      virtualisation.quadlet.containers = {
        homeassistant = lib.mkIf config.modules.containers.homeassistant (
          config.utils.mkContainer {
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
          }
        );

        evcc = lib.mkIf config.modules.containers.evcc (
          config.utils.mkContainer {
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
          }
        );

        mongo = lib.mkIf config.modules.containers.mongo (
          config.utils.mkContainer {
            containerConfig = {
              image = "mongo:latest";
              environments = {
                MONGO_INITDB_ROOT_USERNAME = "admin";
                MONGO_INITDB_ROOT_PASSWORD = "secretpassword";
              };
              volumes = [ "${config.users.users.colin.home}/mongo_data:/data/db" ];
              publishPorts = [ "27017:27017" ];
            };
          }
        );
      };

      networking.firewall.allowedTCPPorts = lib.mkMerge [
        (lib.mkIf config.modules.containers.homeassistant [ 8123 ])
        (lib.mkIf config.modules.containers.evcc [
          7070
          8887
        ])
        (lib.mkIf config.modules.containers.mongo [ 27017 ])
      ];
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services = {
        automation-homeassistant = lib.mkIf config.modules.containers.homeassistant {
          name = "Home Assistant";
          domainName = "hass";
          addr = "127.0.0.1:8123";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/home-assistant.png";
          category = "Automation";
        };

        automation-evcc = lib.mkIf config.modules.containers.evcc {
          name = "evcc";
          domainName = "evcc";
          addr = "127.0.0.1:7070";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/evcc.png";
          category = "Automation";
        };
      };
    };
}
