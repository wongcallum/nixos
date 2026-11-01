{ lib, ... }:
{
  flake.modules.generic.utils =
    { config, ... }:
    {
      options.utils = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified;
        default = { };
      };

      config.utils = rec {
        persistDir = lib.attrByPath [ "modules" "persistence" "persistDir" ] "" config;

        dataDir = name: "${persistDir}/data/${name}";

        cacheDir =
          name: "${lib.attrByPath [ "modules" "persistence" "cacheDir" ] "/var/cache" config}/${name}";

        mkContainer =
          args:
          lib.recursiveUpdate {
            serviceConfig = {
              Restart = "always";
              RestartSec = "10";
            };
            containerConfig = {
              environments = {
                PGID = "1000";
                PUID = "1000";
                TZ = config.time.timeZone;
              };
            };
          } args;
      };
    };
}
