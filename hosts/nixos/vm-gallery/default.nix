{ config, microvmLib, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos."hosts/nixos/vm-gallery" =
    { config, ... }:
    {
      imports = [
        (microvmLib.mkGuestModule {
          n = 1;
          hostname = "vm-gallery";
        })
      ]
      ++ (with nixos; [
        persistence
        sops

        ssh

        cloudflared
        quadlet-gallery
      ]);

      system.stateVersion = "25.11";

      environment.persistence."/persist".directories = [
        "/var/lib/containers"
      ];

      virtualisation.quadlet.containers.gallery-app.containerConfig.publishPorts = [ "3000:3000" ];

      modules.cloudflared = {
        tunnelId = "9b0e8012-83b7-4b5f-a336-d0edd86ec586";
        ingress."gallery.callumwong.com" = "http://127.0.0.1:3000";
      };

      sops.secrets."passwords/vm-gallery-root" = {
        owner = "root";
        group = "root";
        mode = "0400";
        neededForUsers = true;
      };

      users.users.root.hashedPasswordFile = config.sops.secrets."passwords/vm-gallery-root".path;
    };
}
