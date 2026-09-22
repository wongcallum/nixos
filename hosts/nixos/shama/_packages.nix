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
    trilium-desktop
    xournalpp
    scrcpy
    (obs-studio.override { browserSupport = false; })
    picard
    equibop
    feishin
    faugus-launcher
    tigervnc
    openscq30-cli
  ];
}
