{
  lib,
  vmLib,
  ...
}:
let
  exporterPorts = {
    node = 9002;
    smartctl = 9003;
    zfs = 9004;
    cadvisor = 9005;
  };
in
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

      hostAddrs = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Tailscale IP address per hostname";
      };

      metrics.ports = lib.mkOption {
        type = lib.types.attrsOf lib.types.port;
        default = exporterPorts;
        readOnly = true;
        description = "Port each exporter listens on, shared by the exporting and scraping hosts.";
      };

      metrics.hosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              exporters = lib.mkOption {
                type = lib.types.listOf (lib.types.enum (lib.attrNames exporterPorts));
              };

              address = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Address liz scrapes, for VMs reached over their own link instead of Tailscale.";
              };

              smartctlDevices = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Disks for the smartctl exporter, as `/dev/disk/by-id` names without
                  the prefix. Empty means autodiscovery, which also finds transient USB
                  enclosures. One that stops answering SMART blocks every scrape until
                  it's unplugged.
                '';
              };
            };
          }
        );
        default = { };
        description = "Exporters to enable and scrape per host";
      };

      monitoring.host = lib.mkOption {
        type = lib.types.str;
        default = "liz";
        description = "control tower";
      };

      monitoring.lokiPort = lib.mkOption {
        type = lib.types.port;
        default = 3100;
        readOnly = true;
      };

      users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "user account";
              lockPassword = lib.mkEnableOption ''
                a locked password instead of the user's usual one (from nix-secrets or
                initialPassword), leaving SSH keys and passwordless sudo
              '';
            };
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
        media-pelagica = lib.mkEnableOption "Pelagica";
        media-slskd = lib.mkEnableOption "slskd";

        homeassistant = lib.mkEnableOption "Home Assistant";
        mongo = lib.mkEnableOption "MongoDB";

        gitea = lib.mkEnableOption "Gitea";

        searxng = lib.mkEnableOption "SearXNG";

        gallery = lib.mkEnableOption "Gallery";

        immich = lib.mkEnableOption "Immich";

        lobehub = lib.mkEnableOption "LobeHub";
        leafwiki = lib.mkEnableOption "LeafWiki";
      };
    };

    config.modules = {
      hostAddrs = {
        acid = "100.69.159.43";
        eberouge = "100.75.221.118";
        liz = "100.103.248.5";
        salt = "100.83.198.98";
        shama = "100.66.58.20";
      };

      metrics.hosts = {
        eberouge.exporters = [ "node" ];
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
      }
      // lib.mapAttrs (_: vm: {
        exporters = [ "node" ];
        address = vm.guestAddr;
      }) vmLib.vms;
    };
  };
}
