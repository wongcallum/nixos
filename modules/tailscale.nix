{ lib, ... }:
{
  flake.modules.nixos.tailscale = {
    modules.tailscale.enable = lib.mkDefault true;

    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      openFirewall = true;
    };

    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };

  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.modules.tailscale.enable
          [
            "/var/lib/tailscale"
          ];
    };
}
