{ lib, ... }:
{
  flake.modules.nixos.tailscale =
    { config, ... }:
    {
      services.tailscale.enable = true;
      services.tailscale.useRoutingFeatures = "server";

      networking.firewall = {
        trustedInterfaces = [ "tailscale0" ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };
    };

  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.services.tailscale.enable
          [
            "/var/lib/tailscale"
          ];
    };
}
