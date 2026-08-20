let
  host = "127.0.0.1";
  port = 12783;
  memosHost = "127.0.0.1";
  memosPort = 5230;
in
{
  flake.modules.nixos = {
    trilium =
      {
        config,
        inputs,
        pkgs,
        ...
      }:
      {
        services.trilium-server = {
          enable = true;
          # Stable nixpkgs' 0.102.2 crashes during first-run setup when its
          # hourly session cleanup queries the uninitialized database.
          package = inputs.unstable.legacyPackages.${pkgs.system}.trilium-server;
          dataDir = config.utils.dataDir "trilium";
          inherit host port;
        };
      };

    memos =
      { config, ... }:
      let
        dataDir = config.utils.dataDir "memos";
      in
      {
        services.memos = {
          enable = true;
          inherit dataDir;
          settings = {
            MEMOS_MODE = "prod";
            MEMOS_ADDR = memosHost;
            MEMOS_PORT = toString memosPort;
            MEMOS_DATA = dataDir;
            MEMOS_DRIVER = "sqlite";
            MEMOS_INSTANCE_URL = "https://memos.${config.modules.gateway.tld}";
          };
        };
      };

    gateway =
      { config, lib, ... }:
      {
        modules.gateway.services.trilium = lib.mkIf config.services.trilium-server.enable {
          name = "Trilium Notes";
          domainName = "trilium";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/trilium.png";
          addr = "${host}:${toString port}";
          category = "Productivity";
        };

        modules.gateway.services.memos = lib.mkIf config.services.memos.enable {
          name = "Memos";
          domainName = "memos";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/memos.svg";
          addr = "${memosHost}:${toString memosPort}";
          category = "Productivity";
        };
      };
  };
}
