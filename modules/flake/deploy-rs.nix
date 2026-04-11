{
  inputs,
  self,
  lib,
  ...
}:
{
  # define to allow merging by flake-parts
  options.flake.deploy = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  config.flake.checks = builtins.mapAttrs (
    system: deployLib: deployLib.deployChecks self.deploy
  ) inputs.deploy-rs.lib;
}
