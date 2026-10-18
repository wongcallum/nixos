{ inputs, ... }:
let
  mkShell =
    pkgs:
    pkgs.mkShellNoCC {
      packages = [
        pkgs.deadnix
        # each host's toplevel is already a flake check (and built by CI), so
        # deploy-rs's own `nix flake check` would only rebuild every host
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

  # Only the devshell for the Intel Mac: adding it to `systems` would also
  # evaluate the Linux-only packages and checks, from an unstable that has
  # dropped x86_64-darwin
  flake.devShells.x86_64-darwin.default = mkShell (
    import inputs.nixpkgs {
      system = "x86_64-darwin";
      config.allowUnfree = true;
    }
  );
}
