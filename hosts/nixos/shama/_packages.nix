{ inputs, pkgs, ... }:
let
  openscq30-cli = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.openscq30-cli;
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
    kicad
    tigervnc
    openscq30-cli
  ];
}
