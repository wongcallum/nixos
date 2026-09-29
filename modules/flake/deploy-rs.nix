{
  inputs,
  self,
  config,
  lib,
  ...
}:
let
  system = "x86_64-linux";

  pkgs = import inputs.nixpkgs { inherit system; };

  deployPkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      inputs.deploy-rs.overlays.default
      (_: super: {
        deploy-rs = {
          inherit (pkgs) deploy-rs;
          inherit (super.deploy-rs) lib;
        };
      })
    ];
  };

  ciDeploy = self.deploy // {
    nodes = lib.filterAttrs (
      hostname: _: builtins.elem hostname config.flake.ciHosts
    ) self.deploy.nodes;
  };
in
{
  # define to allow merging by flake-parts
  options.flake.deploy = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  config._module.args.deployLib = deployPkgs.deploy-rs.lib;

  config.flake = {
    checks.${system} = {
      inherit (deployPkgs.deploy-rs.lib.deployChecks ciDeploy) deploy-schema;
    };

    # What nixbot builds (see nixbot.toml). deploy-schema evaluates every host
    # at once and blows through nixbot's hard eval memory cap, while each
    # host's toplevel is already its own check.
    ciChecks.${system} = removeAttrs config.flake.checks.${system} [ "deploy-schema" ];
  };
}
