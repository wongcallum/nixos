{ lib, ... }:
{
  # requires flake.modules.nixos.sops
  flake.modules.nixos.cloudflared =
    { config, pkgs, ... }:
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

        credentialsSecret = lib.mkOption {
          type = lib.types.str;
          default = "cloudflared/credentials.json";
          description = ''
            sops key holding this host's tunnel credentials
          '';
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
          sops.secrets.${cfg.credentialsSecret} = {
            restartUnits = [ "cloudflared-tunnel-${cfg.tunnelId}.service" ];
          };

          services.cloudflared = {
            enable = true;

            # workaround: cloudflared-2026-10-2
            # Cloudflare requires >= 2026.10.2; this is release-26.05's 2026.10.3
            package = lib.mkIf (lib.versionOlder pkgs.cloudflared.version "2026.10.2") (
              (pkgs.cloudflared.override { buildGoModule = pkgs.buildGo127Module; }).overrideAttrs (old: {
                version = "2026.10.3";
                src = old.src.override {
                  tag = "2026.10.3";
                  hash = "sha256-k1OMkHHItOT5VHhQqgC8ODm/RCJEtwtZi0Lxyf/esLg=";
                };
                vendorHash = "sha256-KqTLXEm0jxJ1TsyYzxAwYMe8niIgJxBHQPz/aZKmS40=";
                ldflags = map (lib.replaceStrings
                  [ "main.Version=${old.version}" ]
                  [ "main.Version=2026.10.3" ]
                ) old.ldflags;
                preCheck =
                  lib.replaceStrings [ "edgediscovery/protocol_test.go" ] [ "connection/protocol_test.go" ]
                    old.preCheck;
              })
            );

            tunnels.${cfg.tunnelId} = {
              credentialsFile = config.sops.secrets.${cfg.credentialsSecret}.path;
              inherit (cfg) ingress;
              default = "http_status:404";
            };
          };
        })
      ];
    };
}
