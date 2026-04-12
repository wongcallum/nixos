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
        persistDir = lib.attrByPath [ "persistence" "persistDir" ] "" config;

        dataDir = name: "${persistDir}/data/${name}";
      };
    };
}
