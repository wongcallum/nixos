{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.deadnix
          pkgs.deploy-rs
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
