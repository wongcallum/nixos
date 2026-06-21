{
  inputs,
  self,
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
in
{
  # define to allow merging by flake-parts
  options.flake.deploy = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  config._module.args.deployLib = deployPkgs.deploy-rs.lib;
  config.flake.checks.${system} = deployPkgs.deploy-rs.lib.deployChecks self.deploy;
}
