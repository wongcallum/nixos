{ inputs, ... }:
let
  mkShell =
    pkgs:
    pkgs.mkShellNoCC {
      packages = [
        pkgs.deadnix
        # deploy-rs's own flake check would rebuild every host.
        (pkgs.writeShellScriptBin "deploy" ''
          exec ${pkgs.deploy-rs}/bin/deploy --skip-checks "$@"
        '')
        pkgs.nixfmt-tree
        pkgs.nixos-anywhere
        inputs.nix-secrets.packages.${pkgs.stdenv.hostPlatform.system}.nix-secrets
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

      # Builds the devshell in CI, which pushes it to attic.
      checks.devshell = config.devShells.default;
    };

  # Not in `systems`, because unstable has dropped x86_64-darwin.
  flake.devShells.x86_64-darwin.default = mkShell (
    import inputs.nixpkgs {
      system = "x86_64-darwin";
      config.allowUnfree = true;
    }
  );
}
