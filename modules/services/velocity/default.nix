{ inputs, ... }:
{
  flake.modules.nixos.velocity =
    { config, lib, pkgs, ... }:
    {
      imports = [ inputs.flux.nixosModules.default ];

      options.modules.velocity = {
        enable = lib.mkEnableOption "Velocity Minecraft proxy" // {
          default = true;
        };
      };

      config = lib.mkIf config.modules.velocity.enable {
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
      };
    };
}
