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
            environments = {
              # TODO: i will also need to derive this from the config later on
              JELLYFIN_PublishedServerUrl = "https://watch.media.7sref";
            };
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

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "Sonarr";
        domainName = "tv.media";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/sonarr.png";
        addr = "172.21.0.3:8989";
        category = "Media";
      }
      {
        name = "Radarr";
        domainName = "movies.media";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/radarr.png";
        addr = "172.21.0.4:7878";
        category = "Media";
      }
      {
        name = "Prowlarr";
        domainName = "indexers.media";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prowlarr.png";
        addr = "172.21.0.5:9696";
        category = "Media";
      }
      {
        name = "qBittorrent";
        domainName = "torrent.media";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/qbittorrent.png";
        addr = "172.21.0.2:11090";
        category = "Media";
      }
      {
        name = "Jellyfin";
        domainName = "watch.media";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jellyfin.png";
        addr = "172.21.0.7:8096";
        category = "Media";
      }
      # {
      #   name = "FlareSolverr";
      #   domainName = "flaresolverr.media";
      #   iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/flaresolverr.png";
      #   addr = "172.21.0.6:8191";
      #   category = "Media";
      #   hidden = true;
      # }
    ];
  };
}
