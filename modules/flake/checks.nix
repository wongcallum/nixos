{ config, lib, ... }:
let
  system = "x86_64-linux";
in
{
  # define to allow merging by flake-parts
  options.flake.ciHosts = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Hosts whose toplevel CI builds as a flake check.";
  };

  config = {
    # intentionally omitted: staging, minimal-iso, kde-iso
    flake.ciHosts = [
      "acid"
      "liz"
      "salt"
      "shama"
      "vm-coder"
      "vm-gallery"
      "vm-gpu"
    ];

    flake.checks.${system} = lib.genAttrs config.flake.ciHosts (
      hostname: config.flake.nixosConfigurations.${hostname}.config.system.build.toplevel
    );
  };
}
