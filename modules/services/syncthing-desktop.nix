{ lib, ... }:
{
  flake.modules.nixos.syncthing-desktop =
    { config, ... }:
    {
      options.modules.syncthing-desktop.user = lib.mkOption {
        type = lib.types.str;
        description = "User account that syncthing runs as on this desktop host.";
      };

      config.services.syncthing = {
        enable = true;
        openDefaultPorts = true;
        user = config.modules.syncthing-desktop.user;
        dataDir = "/home/${config.modules.syncthing-desktop.user}";
      };
    };
}
