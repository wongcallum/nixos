{ config, vmLib, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos."hosts/nixos/vm-gallery" =
    { config, ... }:
    {
      imports = [
        (vmLib.mkGuestModule {
          hostname = "vm-gallery";
          lockRoot = true;
        })
      ]
      ++ (with nixos; [
        persistence
        secrets

        ssh

        cloudflared
        quadlet-gallery
      ]);

      system.stateVersion = "25.11";

      environment.persistence.${config.modules.persistence.persistDir}.directories = [
        "/var/lib/containers"
      ];

      virtualisation.quadlet.containers.gallery-app.containerConfig.publishPorts = [ "3000:3000" ];

      modules.cloudflared = {
        tunnelId = "3b2b04b1-c342-4988-afb1-6be0ccf1964c";
        ingress."gallery.callumwong.com" = "http://127.0.0.1:3000";
      };
    };
}
