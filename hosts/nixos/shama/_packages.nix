{ inputs, pkgs, ... }:
let
  openscq30-cli = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.openscq30-cli;
  hermes-desktop = pkgs.callPackage ../../../packages/hermes-desktop {
    hermesSrc = inputs.hermes-agent;
  };
in
{
  imports = with inputs.self.modules.nixos; [
    helium
  ];

  environment.systemPackages = with pkgs; [
    coder
    libreoffice-stable
    trilium-desktop
    xournalpp
    scrcpy
    obs-studio
    picard
    equibop
    feishin
    ayugram-desktop
    faugus-launcher
    hermes-desktop
    openscq30-cli
  ];
}
