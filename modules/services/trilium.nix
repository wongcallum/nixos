let
  host = "127.0.0.1";
  port = 12783;
in
{
  flake.modules.nixos.trilium =
    { config, ... }:
    {
      services.trilium-server = {
        enable = true;
        dataDir = config.utils.dataDir "trilium";
        inherit host;
        inherit port;
      };
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "Trilium Notes";
        domainName = "trilium";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/trilium.png";
        addr = "${host}:${toString port}";
        category = "Productivity";
      }
    ];
  };
}
