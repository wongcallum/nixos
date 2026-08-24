{ inputs, lib, ... }:
{
  flake.modules.nixos.mc-server =
    { config, ... }:
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "minecraft-server"} 0755 root root -"
      ];

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
                image = "itzg/minecraft-server:latest";
                podmanArgs = [
                  "--attach"
                  "stdin"
                  "--tty"
                  "--publish"
                  "25565:25565"
                ];
                environments = {
                  EULA = "TRUE";
                  VERSION = "26.2";
                  MEMORY = "6144M";
                  USE_MEOWICE_FLAGS = "true";
                  TYPE = "FABRIC";
                };
                exposePorts = [ "25565" ];
                volumes = [ "${config.utils.dataDir "minecraft-server"}:/data" ];
                stopTimeout = 60;
              };
            }
          );

      networking.firewall.allowedTCPPorts = lib.mkIf config.modules.containers.minecraft-server [ 25565 ];
    };
}
