{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.deploy-rs
          pkgs.nixos-anywhere
          pkgs.sops
          pkgs.ssh-to-age
        ];
      };
    };
}
