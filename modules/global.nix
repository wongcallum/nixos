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

            options.smartctlDevices = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Disks to hand the smartctl exporter, as `/dev/disk/by-id` names;
                the prefix is added for you. Empty means autodiscovery, which
                also finds transient USB enclosures - one that stops answering
                SMART blocks every scrape until it is unplugged.
              '';
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
        media-slskd = lib.mkEnableOption "slskd";

        homeassistant = lib.mkEnableOption "Home Assistant";
        mongo = lib.mkEnableOption "MongoDB";

        gitea = lib.mkEnableOption "Gitea";

        searxng = lib.mkEnableOption "SearXNG";

        cottage-witch = lib.mkEnableOption "Minecraft Server (Cottage Witch)";
        minecraft-server = lib.mkEnableOption "Minecraft Server";

        gallery = lib.mkEnableOption "Gallery";

        immich = lib.mkEnableOption "Immich";

        lobehub = lib.mkEnableOption "LobeHub";
        onlyboxes = lib.mkEnableOption "OnlyBoxes";
        gotosocial = lib.mkEnableOption "GoToSocial";
      };
    };

    config.modules = {
      hostAddrs = {
        liz = "100.103.248.5";
        salt = "100.83.198.98";
        staging = "100.103.202.124";
      };

      metrics.hosts = {
        liz.exporters = [
          "node"
          "zfs"
          "smartctl"
          "cadvisor"
        ];
        liz.smartctlDevices = [
          "ata-WDC_WD20EARX-00AZ6B0_WD-WCC070091856"
          "ata-WDC_WD20EARX-00AZ6B0_WD-WCC070060070"
          "ata-WDC_WD20EZRX-00D8PB0_WD-WMC4M0186106"
          "ata-WDC_WD20EARX-00AZ6B0_WD-WCC070117894"
          "ata-WDC_WD10EZEX-60WN4A0_WD-WCC6Y3UDHH34"
          "ata-ST2000DM001-1CH164_W3406XDY"
          "nvme-Patriot_M.2_P300_128GB_P300ADBB22111800174"
          "nvme-Samsung_SSD_980_PRO_1TB_S5GXNX0T913718H"
        ];
        salt.exporters = [
          "node"
          "cadvisor"
        ];
      };
    };
  };
}
