{ inputs, lib, ... }:
{
  flake.modules.nixos.mc-server =
    { config, ... }:
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      modules.containers = {
        minecraft-server = lib.mkDefault true;
      };

      virtualisation.quadlet.containers.minecraft-server =
        lib.mkIf config.modules.containers.minecraft-server
          (
            config.utils.mkContainer {
              serviceConfig = {
                TimeoutStartSec = "120";
              };
              containerConfig = {
                image = "itzg/minecraft-server:java17";
                podmanArgs = [
                  "--attach"
                  "stdin"
                  "--tty"
                  "--publish"
                  "25565:25565"
                ];
                environments = {
                  EULA = "TRUE";
                  VERSION = "1.19.2";
                  MEMORY = "6144M";
                  USE_MEOWICE_FLAGS = "true";
                  TYPE = "FORGE";
                  # PACKWIZ_URL = "https://asphodel.cc/packwiz/Ports/Curse/Raspberry-Server/pack.toml";
                  MODRINTH_PROJECTS = ''
                    proxy-compatible-forge
                    # proxy-protocol-support:1.1.0-forge
                    spark
                    chunky
                    collective
                    # beautified-chat-server
                    no-telemetry
                    keepheadnames
                    # grieflogger
                  '';
                };
                exposePorts = [ "25565" ];
                # volumes = [ "/data/raspberry:/data" ];
                volumes = [ "/data/cottage-witch:/data" ];
                stopTimeout = 60;
                notify = "healthy";
                healthStartPeriod = "60s";
              };
            }
          );

      networking.firewall.allowedTCPPorts =
        lib.mkIf config.modules.containers.minecraft-server [ 25565 ];
    };
}
