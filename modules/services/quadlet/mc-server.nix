{
  flake.modules.nixos.mc-server = {
    virtualisation.quadlet.containers.minecraft-server = {
      serviceConfig = {
        RestartSec = "10";
        Restart = "always";
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
        # healthcheck will always fail
        healthInterval = "disable";
      };
    };
  };
}
