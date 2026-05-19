{
  flake.modules.nixos.syncthing-server =
    { config, ... }:
    {
      sops.secrets."syncthing/key.pem" = {
        owner = "syncthing";
        group = "syncthing";
        mode = "0440";
      };

      sops.secrets."syncthing/cert.pem" = {
        owner = "syncthing";
        group = "syncthing";
        mode = "0440";
      };

      services.syncthing = {
        enable = true;
        openDefaultPorts = true;
        dataDir = config.utils.dataDir "syncthing";
        configDir = config.utils.dataDir "syncthing";
        key = config.sops.secrets."syncthing/key.pem".path;
        cert = config.sops.secrets."syncthing/cert.pem".path;
        # STOP FUCKING WIPING MY CONFIG!
        overrideDevices = false;
        overrideFolders = false;
        settings = {
          gui.insecureSkipHostcheck = true;
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.syncthing = lib.mkIf config.services.syncthing.enable {
        name = "Syncthing";
        domainName = "syncthing";
        addr = "127.0.0.1:8384";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/syncthing.png";
        category = "Administration";
      };
    };
}
