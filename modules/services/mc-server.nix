{
  flake.modules.nixos.mc-server =
    { config, ... }:
    {
      virtualisation.quadlet =
        let
          inherit (config.virtualisation.quadlet) networks pods volumes;
        in
        {
          containers = {
            raspberry-server = {
              serviceConfig = {
                RestartSec = "10";
                Restart = "always";
                TimeoutStartSec = "120";
              };
              containerConfig = {
                image = "itzg/minecraft-server:java21-alpine";
                podmanArgs = [
                  "--attach"
                  "stdin"
                  "--tty"
                ];
                pod = pods.minecraft.ref;
                environments = {
                  EULA = "TRUE";
                  VERSION = "1.19.2";
                  MEMORY = "6144M";
                  USE_MEOWICE_FLAGS = "true";
                  TYPE = "FORGE";
                  PACKWIZ_URL = "https://asphodel.cc/packwiz/Ports/Curse/Raspberry-Server/pack.toml";
                  MODRINTH_PROJECTS = ''
                    # proxy-compatible-forge
                    proxy-protocol-support:1.1.0-forge
                    spark
                    chunky
                    collective
                    beautified-chat-server
                    no-telemetry
                    keepheadnames
                    grieflogger
                  '';
                };
                exposePorts = [ "25565" ];
                volumes = [ "${volumes.minecraft.ref}:/data" ];
                stopTimeout = 60;
                # healthcheck will always fail
                healthInterval = "disable";
              };
            };
          };
          volumes.minecraft.volumeConfig = {
            type = "bind";
            device = "/data/minecraft";
          };
          networks = {
            internal.networkConfig.subnets = [ "10.0.67.1/24" ];
          };
          pods = {
            minecraft.podConfig = {
              networks = [ networks.internal.ref ];
              publishPorts = [ "25565:25565" ];
            };
          };
        };
    };
}
