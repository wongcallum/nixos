{
  inputs,
  self,
  config,
  lib,
  ...
}:
let
  system = "x86_64-linux";

  mkDeployPkgs =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.deploy-rs.overlays.default
        (_: super: {
          deploy-rs = {
            inherit (inputs.nixpkgs.legacyPackages.${system}) deploy-rs;
            inherit (super.deploy-rs) lib;
          };
        })
      ];
    };

  deployPkgs = mkDeployPkgs system;

  ciDeploy = self.deploy // {
    nodes = lib.filterAttrs (
      hostname: _: builtins.elem hostname config.flake.ciHosts
    ) self.deploy.nodes;
  };
in
{
  # Declared so flake-parts can merge definitions.
  options.flake.deploy = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  config._module.args.deployLibFor = s: (mkDeployPkgs s).deploy-rs.lib;

  config.flake = {
    checks.${system} = {
      inherit (deployPkgs.deploy-rs.lib.deployChecks ciDeploy) deploy-schema;
    };

    # deploy-schema evaluates every host at once and exceeds nixbot's eval memory cap.
    ciChecks.${system} = removeAttrs config.flake.checks.${system} [ "deploy-schema" ];
  };
}
