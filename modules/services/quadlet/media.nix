let
  networkName = "media";
in
{
  flake.modules.nixos.quadlet-media =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      virtualisation.quadlet = {
        networks.${networkName}.networkConfig = {
          subnets = [ "172.21.0.0/16" ];
          disableDns = true;
        };

        containers.media-sonarr = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "ghcr.io/hotio/sonarr:latest";
            environments = {
              PGID = "1000";
              PUID = "1000";
              TZ = "Sydney/Australia";
            };
            volumes = [
              "/mnt/media:/data:rw"
              "${config.utils.dataDir "media/sonarr"}:/config:rw"
            ];
            networks = [ networks.${networkName}.ref ];
            ip = "172.21.0.3";
          };
        };

        containers.media-radarr = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "ghcr.io/hotio/radarr:latest";
            environments = {
              PGID = "1000";
              PUID = "1000";
              TZ = "Sydney/Australia";
            };
            volumes = [
              "/mnt/media:/data:rw"
              "${config.utils.dataDir "media/radarr"}:/config:rw"
            ];
            networks = [ networks.${networkName}.ref ];
            ip = "172.21.0.4";
          };
        };

        containers.media-prowlarr = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "ghcr.io/hotio/prowlarr:latest";
            environments = {
              PGID = "1000";
              PUID = "1000";
              TZ = "Sydney/Australia";
            };
            volumes = [ "${config.utils.dataDir "media/prowlarr"}:/config:rw" ];
            networks = [ networks.${networkName}.ref ];
            ip = "172.21.0.5";
          };
        };

        containers.media-flaresolverr = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "ghcr.io/flaresolverr/flaresolverr:latest";
            environments = {
              CAPTCHA_SOLVER = "none";
              LOG_HTML = "false";
              LOG_LEVEL = "info";
              TZ = "Australia/Sydney";
            };
            networks = [ networks.${networkName}.ref ];
            ip = "172.21.0.6";
          };
        };

        containers.media-qbittorrent = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "ghcr.io/hotio/qbittorrent:latest";
            environments = {
              PGID = "1000";
              PUID = "1000";
              TZ = "Sydney/Australia";
              WEBUI_PORTS = "11090/tcp";
            };
            volumes = [
              "/mnt/media/torrents:/data/torrents:rw"
              "${config.utils.dataDir "media/qbittorrent"}:/config:rw"
            ];
            networks = [ networks.${networkName}.ref ];
            ip = "172.21.0.2";
          };
        };

        containers.media-jellyfin = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "jellyfin/jellyfin";
            # healthcheck systemd unit exits non-zero while status is "starting", preventing successful deploy
            healthInterval = "disable";
            volumes = [
              "/mnt/media/media:/media:rw"
              "${config.utils.dataDir "media/jellyfin/cache"}:/cache:rw"
              "${config.utils.dataDir "media/jellyfin/config"}:/config:rw"
            ];
            networks = [ networks.${networkName}.ref ];
            ip = "172.21.0.7";
          };
        };
      };
    };

  flake.modules.nixos.gateway =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      jellyfinDomainName = "watch.media";
    in
    lib.mkIf (options.virtualisation ? quadlet) {
      virtualisation.quadlet.containers.media-jellyfin.containerConfig.environments.JELLYFIN_PublishedServerUrl =
        "${jellyfinDomainName}.${config.modules.gateway.tld}";

      modules.gateway.localServices = lib.mkMerge [
        (lib.optional (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "media-sonarr" ] config)
          {
            name = "Sonarr";
            domainName = "tv.media";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/sonarr.png";
            addr = "172.21.0.3:8989";
            category = "Media";
          }
        )
        (lib.optional (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "media-radarr" ] config)
          {
            name = "Radarr";
            domainName = "movies.media";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/radarr.png";
            addr = "172.21.0.4:7878";
            category = "Media";
          }
        )
        (lib.optional
          (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "media-prowlarr" ] config)
          {
            name = "Prowlarr";
            domainName = "indexers.media";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prowlarr.png";
            addr = "172.21.0.5:9696";
            category = "Media";
          }
        )
        (lib.optional
          (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "media-qbittorrent" ] config)
          {
            name = "qBittorrent";
            domainName = "torrent.media";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/qbittorrent.png";
            addr = "172.21.0.2:11090";
            category = "Media";
          }
        )
        (lib.optional
          (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "media-jellyfin" ] config)
          {
            name = "Jellyfin";
            domainName = jellyfinDomainName;
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jellyfin.png";
            addr = "172.21.0.7:8096";
            category = "Media";
          }
        )
        (lib.optional
          (lib.hasAttrByPath [ "virtualisation" "quadlet" "containers" "media-flaresolverr" ] config)
          {
            name = "FlareSolverr";
            domainName = "flaresolverr.media";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/flaresolverr.png";
            addr = "172.21.0.6:8191";
            category = "Media";
            hidden = true;
          }
        )
      ];
    };
}
