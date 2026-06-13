{ lib, ... }:
{
  flake.modules.nixos.global = _: {
    options.modules = {
      gateway.tld = lib.mkOption {
        type = lib.types.str;
        default = "7sref";
        description = "Top-level domain for services";
      };

      ssh.enable = lib.mkEnableOption "OpenSSH";
      tailscale.enable = lib.mkEnableOption "Tailscale";
      fonts.enable = lib.mkEnableOption "fonts";
      samba.enable = lib.mkEnableOption "Samba";
      velocity.enable = lib.mkEnableOption "Velocity proxy";

      hostAddrs = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "hostname to tailscale IP address";
      };

      metrics.hosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.exporters = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "node"
                  "zfs"
                  "smartctl"
                  "cadvisor"
                ]
              );
            };
          }
        );
        default = { };
        description = "which exporters to enable and scrape per host";
      };

      monitoring.host = lib.mkOption {
        type = lib.types.str;
        default = "liz";
        description = "control tower";
      };

      users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.enable = lib.mkEnableOption "user account";
          }
        );
        default = { };
      };

      containers = {
        media-sonarr = lib.mkEnableOption "Sonarr";
        media-radarr = lib.mkEnableOption "Radarr";
        media-prowlarr = lib.mkEnableOption "Prowlarr";
        media-flaresolverr = lib.mkEnableOption "FlareSolverr";
        media-qbittorrent = lib.mkEnableOption "qBittorrent";
        media-jellyfin = lib.mkEnableOption "Jellyfin";

        homeassistant = lib.mkEnableOption "Home Assistant";
        evcc = lib.mkEnableOption "evcc";
        mongo = lib.mkEnableOption "MongoDB";

        forgejo = lib.mkEnableOption "Forgejo";

        ai-searxng = lib.mkEnableOption "SearXNG";
        ai-openwebui = lib.mkEnableOption "Open WebUI";
        silverbullet = lib.mkEnableOption "SilverBullet";

        minecraft-server = lib.mkEnableOption "Minecraft Server";

        gallery = lib.mkEnableOption "Gallery";

        immich = lib.mkEnableOption "Immich";

        lobehub = lib.mkEnableOption "LobeHub";
      };
    };

    config.modules = {
      hostAddrs = {
        liz = "100.103.248.5";
        milk = "100.83.57.121";
        salt = "100.83.198.98";
        staging = "100.103.202.124";
        vm-gallery = "100.93.214.80";
        wky = "100.79.128.120";
      };

      metrics.hosts = {
        liz.exporters = [
          "node"
          "zfs"
          "smartctl"
          "cadvisor"
        ];
        milk.exporters = [ "node" ];
        salt.exporters = [
          "node"
          "cadvisor"
        ];
      };
    };
  };
}
