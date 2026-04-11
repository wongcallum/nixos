{ inputs, lib, ... }:
{
  flake.modules.nixos.persistence =
    { config, ... }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      options.persistence = {
        persistDir = lib.mkOption {
          type = lib.types.str;
          default = "/persist";
        };
      };

      config = {
        fileSystems.${config.persistence.persistDir}.neededForBoot = true;

        environment.persistence.${config.persistence.persistDir} = {
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
