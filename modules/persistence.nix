{ inputs, lib, ... }:
{
  flake.modules.nixos.persistence =
    { config, ... }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      options.modules.persistence = {
        persistDir = lib.mkOption {
          type = lib.types.str;
          default = "/persist";
        };
      };

      config = {
        fileSystems.${config.modules.persistence.persistDir}.neededForBoot = true;

        environment.persistence.${config.modules.persistence.persistDir} = {
          enable = true;
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/log"
          ];
          files = [
            "/etc/machine-id"
          ];
        };
      };
    };
}
