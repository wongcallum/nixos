let
  networkName = "media";
  jellyfinDomainName = "watch.media";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-media =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "media/sonarr"} 0755 root root -"
        "d ${config.utils.dataDir "media/radarr"} 0755 root root -"
        "d ${config.utils.dataDir "media/prowlarr"} 0755 root root -"
        "d ${config.utils.dataDir "media/qbittorrent"} 0755 root root -"
        "d ${config.utils.dataDir "media/jellyfin/cache"} 0755 root root -"
        "d ${config.utils.dataDir "media/jellyfin/config"} 0755 root root -"
        "d ${config.utils.dataDir "media/slskd"} 0755 root root -"
        "d /mnt/media/soulseek 0755 1000 1000 -"
        "d /mnt/media/soulseek/downloads 0755 1000 1000 -"
        "d /mnt/media/soulseek/incomplete 0755 1000 1000 -"
      ];

      modules.containers = {
        media-sonarr = lib.mkDefault true;
        media-radarr = lib.mkDefault true;
        media-prowlarr = lib.mkDefault true;
        media-flaresolverr = lib.mkDefault true;
        media-qbittorrent = lib.mkDefault true;
        media-jellyfin = lib.mkDefault true;
        media-slskd = lib.mkDefault true;
      };

      sops.secrets."docker/slskd_env" = lib.mkIf config.modules.containers.media-slskd {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "media-slskd.service" ];
      };

      virtualisation.quadlet = {
        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.21.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          media-sonarr = lib.mkIf config.modules.containers.media-sonarr (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/hotio/sonarr:latest";
                volumes = [
                  "/mnt/media:/data:rw"
                  "${config.utils.dataDir "media/sonarr"}:/config:rw"
                ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.3";
              };
            }
          );

          media-radarr = lib.mkIf config.modules.containers.media-radarr (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/hotio/radarr:latest";
                volumes = [
                  "/mnt/media:/data:rw"
                  "${config.utils.dataDir "media/radarr"}:/config:rw"
                ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.4";
              };
            }
          );

          media-prowlarr = lib.mkIf config.modules.containers.media-prowlarr (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/hotio/prowlarr:latest";
                volumes = [ "${config.utils.dataDir "media/prowlarr"}:/config:rw" ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.5";
              };
            }
          );

          media-flaresolverr = lib.mkIf config.modules.containers.media-flaresolverr (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/flaresolverr/flaresolverr:latest";
                environments = {
                  CAPTCHA_SOLVER = "none";
                  LOG_HTML = "false";
                  LOG_LEVEL = "info";
                };
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.6";
              };
            }
          );

          media-qbittorrent = lib.mkIf config.modules.containers.media-qbittorrent (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/hotio/qbittorrent:latest";
                environments = {
                  WEBUI_PORTS = "11090/tcp";
                };
                volumes = [
                  "/mnt/media/torrents:/data/torrents:rw"
                  "${config.utils.dataDir "media/qbittorrent"}:/config:rw"
                ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.2";
              };
            }
          );

          media-jellyfin = lib.mkIf config.modules.containers.media-jellyfin (
            config.utils.mkContainer {
              containerConfig = {
                image = "jellyfin/jellyfin";
                notify = "healthy";
                healthStartPeriod = "30s";
                volumes = [
                  "/mnt/media/media:/media:rw"
                  "${config.utils.dataDir "media/jellyfin/cache"}:/cache:rw"
                  "${config.utils.dataDir "media/jellyfin/config"}:/config:rw"
                ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.7";
                environments.JELLYFIN_PublishedServerUrl = "${jellyfinDomainName}.${config.modules.gateway.tld}";
              };
            }
          );

          media-slskd = lib.mkIf config.modules.containers.media-slskd (
            config.utils.mkContainer {
              containerConfig = {
                image = "slskd/slskd:latest";
                environmentFiles = [ config.sops.secrets."docker/slskd_env".path ];
                environments = {
                  SLSKD_REMOTE_CONFIGURATION = "false";
                  SLSKD_SLSK_LISTEN_PORT = "50300";
                  SLSKD_DOWNLOADS_DIR = "/data/downloads";
                  SLSKD_INCOMPLETE_DIR = "/data/incomplete";
                  SLSKD_SHARED_DIR = "/music";
                  APP_DIR = "/app";
                  SLSKD_DISK_LOGGER = "true";
                };
                publishPorts = [ "50300:50300" ];
                volumes = [
                  "/mnt/media/soulseek:/data:rw"
                  "/mnt/media/media/music:/music:ro"
                  "${config.utils.dataDir "media/slskd"}:/app:rw"
                ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.21.0.8";
              };
            }
          );
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services = {
        media-sonarr = lib.mkIf config.modules.containers.media-sonarr {
          name = "Sonarr";
          domainName = "tv.media";
          addr = "172.21.0.3:8989";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/sonarr.png";
          category = "Media";
        };

        media-radarr = lib.mkIf config.modules.containers.media-radarr {
          name = "Radarr";
          domainName = "movies.media";
          addr = "172.21.0.4:7878";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/radarr.png";
          category = "Media";
        };

        media-prowlarr = lib.mkIf config.modules.containers.media-prowlarr {
          name = "Prowlarr";
          domainName = "indexers.media";
          addr = "172.21.0.5:9696";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prowlarr.png";
          category = "Media";
        };

        media-qbittorrent = lib.mkIf config.modules.containers.media-qbittorrent {
          name = "qBittorrent";
          domainName = "torrent.media";
          addr = "172.21.0.2:11090";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/qbittorrent.png";
          category = "Media";
        };

        media-jellyfin = lib.mkIf config.modules.containers.media-jellyfin {
          name = "Jellyfin";
          domainName = jellyfinDomainName;
          addr = "172.21.0.7:8096";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jellyfin.png";
          category = "Media";
        };

        media-flaresolverr = lib.mkIf config.modules.containers.media-flaresolverr {
          name = "FlareSolverr";
          domainName = "flaresolverr.media";
          addr = "172.21.0.6:8191";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/flaresolverr.png";
          category = "Media";
          hidden = true;
        };

        media-slskd = lib.mkIf config.modules.containers.media-slskd {
          name = "slskd";
          domainName = "soulseek.media";
          addr = "172.21.0.8:5030";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/slskd.png";
          category = "Media";
        };
      };
    };
}
