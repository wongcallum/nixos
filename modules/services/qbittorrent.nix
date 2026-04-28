let
  port = 8888;
in
{
  flake.modules.nixos.qbittorrent =
    { config, pkgs, ... }:
    {
      services.qbittorrent = {
        enable = true;
        webuiPort = port;
        profileDir = "${config.utils.dataDir "qbittorrent"}/";
        serverConfig = {
          Preferences = {
            WebUI = {
              AlternativeUIEnabled = true;
              RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
              HostHeaderValidation = false;
              CSRFProtection = false;
            };
          };
        };
        openFirewall = true;
      };
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "VueTorrent";
        domainName = "torrent";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/vuetorrent.png";
        addr = "127.0.0.1:${toString port}";
        category = "Administration";
      }
    ];
  };
}
