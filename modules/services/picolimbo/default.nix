{ inputs, ... }:
{
  flake.modules.nixos.picolimbo =
    { config, lib, ... }:
    {
      imports = [ inputs.picolimbo.nixosModules.default ];

      options.modules.picolimbo = {
        enable = lib.mkEnableOption "PicoLimbo limbo server";
      };

      config = lib.mkMerge [
        {
          modules.picolimbo.enable = lib.mkDefault true;
        }
        (lib.mkIf config.modules.picolimbo.enable {
          sops.secrets."minecraft/velocity-secret" = {
            restartUnits = [ "picolimbo.service" ];
          };

          services.picolimbo = {
            enable = true;
            openFirewall = true;

            settings = {
              bind = "0.0.0.0:30066";
              welcome_message = "Welcome to Limbo. Return to the real world with /server";
              action_bar = "You are in Limbo.";
              default_game_mode = "spectator";

              forwarding = {
                method = "MODERN";
                secret = "\${VELOCITY_SECRET}";
              };

              world = {
                spawn_position = [
                  0.0
                  320.0
                  0.0
                ];
                dimension = "end";
                experimental = {
                  view_distance = 2;
                  schematic_file = "${./spawn.schem}";
                  lock_time = false;
                };
                boundaries = {
                  enabled = true;
                  min_y = -64;
                  teleport_message = "<red>You have reached the bottom of the world.</red>";
                };
              };

              compression.threshold = -1;
            };
          };

          systemd.services.picolimbo = {
            serviceConfig.LoadCredential =
              "velocity-secret:${config.sops.secrets."minecraft/velocity-secret".path}";
            environment.VELOCITY_SECRET = "%d/velocity-secret";
          };
        })
      ];
    };
}
