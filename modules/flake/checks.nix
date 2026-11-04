{ config, lib, ... }:
let
  system = "x86_64-linux";
in
{
  # Declared so flake-parts can merge definitions.
  options.flake.ciHosts = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Hosts whose toplevel CI builds as a flake check.";
  };

  config = {
    # minimal-iso and kde-iso are left out on purpose.
    flake.ciHosts = [
      "acid"
      "liz"
      "salt"
      "shama"
      "vm-ci"
      "vm-gpu"
      "vm-gallery"
      "vm-thsconline"
    ];

    flake.checks.${system} = lib.genAttrs config.flake.ciHosts (
      hostname: config.flake.nixosConfigurations.${hostname}.config.system.build.toplevel
    );
  };
}
