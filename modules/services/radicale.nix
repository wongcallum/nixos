{ lib, ... }:

let
  port = 5232;
in
{
  flake.modules.nixos.radicale =
    { config, ... }:
    let
      storageDir = config.utils.dataDir "radicale";
    in
    {
      services.radicale = {
        enable = true;
        settings = {
          server.hosts = [ "127.0.0.1:${toString port}" ];
          auth.type = "none";
          storage.filesystem_folder = storageDir;
        };
      };

      # Keep Radicale's collection data on the persistent dataset rather than
      # in the ephemeral /var/lib hierarchy created by StateDirectory.
      systemd.tmpfiles.rules = [
        "d ${storageDir} 0750 radicale radicale -"
      ];
      systemd.services.radicale.serviceConfig = {
        StateDirectory = lib.mkForce "";
        WorkingDirectory = lib.mkForce storageDir;
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.radicale = lib.mkIf config.services.radicale.enable {
        name = "Radicale";
        domainName = "radicale";
        addr = "127.0.0.1:${toString port}";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/radicale.png";
        category = "Productivity";
      };
    };
}
