{ lib, ... }:
{
  # requires flake.modules.nixos.sops
  flake.modules.nixos.cloudflared =
    { config, ... }:
    let
      cfg = config.modules.cloudflared;
    in
    {
      options.modules.cloudflared = {
        tunnelId = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "00000000-0000-0000-0000-000000000000";
          description = "Cloudflare tunnel UUID printed by `cloudflared tunnel create`";
        };

        ingress = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "gallery.callumwong.com" = "http://10.0.0.2:3000";
          };
        };
      };

      config = lib.mkMerge [
        {
          warnings = lib.optional (cfg.ingress != { } && cfg.tunnelId == "") ''
            modules.cloudflared.ingress is set but modules.cloudflared.tunnelId is
            empty, these hostnames are not served:
            ${lib.concatStringsSep ", " (lib.attrNames cfg.ingress)}
          '';
        }

        (lib.mkIf (cfg.tunnelId != "") {
          sops.secrets."cloudflared/credentials.json" = {
            owner = "root";
            group = "root";
            mode = "0400";
            restartUnits = [ "cloudflared-tunnel-${cfg.tunnelId}.service" ];
          };

          services.cloudflared = {
            enable = true;

            tunnels.${cfg.tunnelId} = {
              credentialsFile = config.sops.secrets."cloudflared/credentials.json".path;
              inherit (cfg) ingress;
              default = "http_status:404";
            };
          };
        })
      ];
    };
}
