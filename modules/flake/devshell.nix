{ inputs, ... }:
let
  mkShell =
    pkgs:
    pkgs.mkShellNoCC {
      packages = [
        pkgs.deadnix
        # deploy-rs's flake check would rebuild every host
        (pkgs.writeShellScriptBin "deploy" ''
          exec ${pkgs.deploy-rs}/bin/deploy --skip-checks "$@"
        '')
        pkgs.nixfmt-tree
        pkgs.nixos-anywhere
        pkgs.sops
        pkgs.ssh-to-age
        pkgs.statix
        pkgs.terraform
      ];
    };
in
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = mkShell pkgs;

      # push devshell packages to attic
      checks.devshell = config.devShells.default;
    };

  # not in `systems`: unstable has dropped x86_64-darwin
  flake.devShells.x86_64-darwin.default = mkShell (
    import inputs.nixpkgs {
      system = "x86_64-darwin";
      config.allowUnfree = true;
    }
  );
}
