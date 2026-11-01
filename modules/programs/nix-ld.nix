{
  flake.modules.nixos.nix-ld =
    { pkgs, ... }:
    {
      programs.nix-ld = {
        enable = true;
        libraries = [
          (pkgs.runCommand "steamrun-lib" { } "mkdir $out; ln -s ${pkgs.steam-run.fhsenv}/usr/lib64 $out/lib")
          # T3 Code's preview browser (downloaded chrome-headless-shell) needs these beyond steam-run's set.
          pkgs.nss
          pkgs.nspr
          pkgs.atk
          pkgs.at-spi2-atk
          pkgs.at-spi2-core
          pkgs.libxcomposite
        ];
      };
    };
}
