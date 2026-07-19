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
        tailscale

        cloudflared
        quadlet-gallery
      ]);

      system.stateVersion = "25.11";

      environment.persistence."/persist".directories = [
        "/var/lib/containers"
      ];

      virtualisation.quadlet.containers.gallery-app.containerConfig.publishPorts = [ "3000:3000" ];

      # set tunnelId once created
      modules.cloudflared.ingress."gallery.callumwong.com" = "http://127.0.0.1:3000";

      sops.secrets."passwords/vm-gallery-root" = {
        owner = "root";
        group = "root";
        mode = "0400";
        neededForUsers = true;
      };

      users.users.root.hashedPasswordFile = config.sops.secrets."passwords/vm-gallery-root".path;
    };
}
