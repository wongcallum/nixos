let
  port = 8484;
in
{
  flake.modules.nixos.trilium =
    { config, ... }:
    let
      dataDir = config.utils.dataDir "trilium";
    in
    {
      services.trilium-server = {
        enable = true;
        inherit dataDir port;
        instanceName = config.networking.hostName;
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.trilium = lib.mkIf config.services.trilium-server.enable {
        name = "Trilium Notes";
        domainName = "notes";
        addr = "127.0.0.1:${toString port}";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/trilium.png";
        category = "Productivity";
      };
    };
}
