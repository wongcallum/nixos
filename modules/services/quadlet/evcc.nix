{
  flake.modules.nixos.quadlet-evcc =
    { config, ... }:
    {
      virtualisation.quadlet.containers.evcc = {
        serviceConfig = {
          Restart = "always";
          RestartSec = "10";
        };
        containerConfig = {
          image = "evcc/evcc:latest";
          volumes = [
            "${config.users.users.colin.home}/evcc:/root/.evcc"
          ];
          publishPorts = [ "7070:7070" "8887:8887" ];
        };
      };
    };
}
