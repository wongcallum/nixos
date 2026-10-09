{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
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

      # push devshell packages to attic
      checks.devshell = config.devShells.default;
    };
}
