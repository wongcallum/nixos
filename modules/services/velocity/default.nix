{ inputs, ... }:
{
  flake.modules.nixos.velocity =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.flux.nixosModules.default ];

      options.modules.velocity = {
        pluginDataDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "luckperms"
            "velocitab"
          ];
        };
      };

      config = lib.mkMerge [
        { modules.velocity.enable = lib.mkDefault true; }
        (lib.mkIf config.modules.velocity.enable {
          nixpkgs.overlays = [ inputs.flux.overlays.default ];

          flux = {
            enable = true;
            servers.velocity = {
              enable = true;
              package = pkgs.mkMinecraftServer {
                name = "velocity";
                src = ./mcman;
                hash = "sha256-XVRs19FWa51x86j4Rhs3u87c2NuxCUAheOw9s+O/82o=";
                prefetchJars = false;
              };
              proxy.enable = false;
            };
          };

          networking.firewall = {
            allowedTCPPorts = [ 25565 ];
            allowedUDPPorts = [ 25565 ];
          };
        })
      ];
    };

  flake.modules.nixos.persistence =
    { config, lib, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.modules.velocity.enable
          (
            map (name: {
              directory = "/var/lib/flux/velocity/plugins/${name}";
              user = "flux";
              group = "flux";
              mode = "0770";
            }) config.modules.velocity.pluginDataDirs
          );
    };
}
