let
  webuiPort = 8888;
  torrentingPort = 50413;
in
{
  flake.modules.nixos.qbittorrent =
    { config, pkgs, ... }:
    {
      services.qbittorrent = {
        inherit webuiPort torrentingPort;
        enable = true;
        profileDir = "${config.utils.dataDir "qbittorrent"}/";
        serverConfig = {
          BitTorrent.Session = {
            DefaultSavePath = "/tank/torrents";
            AnonymousModeEnabled = true;
            GlobalMaxRatio = 2;
            GlobalMaxSeedingMinutes = 10080;
            # KiB/s
            AlternativeGlobalDLSpeedLimit = 20480;
            AlternativeGlobalUPSpeedLimit = 2048;
            IgnoreSlowTorrentsForQueueing = true;
            MaxActiveTorrents = 20;
            MaxActiveUploads = 10;
            BandwidthSchedulerEnabled = true;
          };
          # QVariant-encoded 08:00 and 20:00, every day
          Preferences.Scheduler = {
            start_time = "@Variant(\\0\\0\\0\\xf\\x1\\xb7t\\0)";
            end_time = "@Variant(\\0\\0\\0\\xf\\x4J\\xa2\\0)";
            days = 0;
          };
          Network.PortForwardingEnabled = false;
          Preferences.WebUI = {
            AlternativeUIEnabled = true;
            RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
            HostHeaderValidation = false;
            CSRFProtection = false;
            LocalHostAuth = false;
          };
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ torrentingPort ];
        allowedUDPPorts = [ torrentingPort ];
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.qbittorrent = lib.mkIf config.services.qbittorrent.enable {
        name = "VueTorrent";
        domainName = "torrent";
        addr = "127.0.0.1:${toString webuiPort}";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/vuetorrent.png";
        category = "Administration";
      };
    };
}
