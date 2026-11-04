{ inputs, pkgs, ... }:
{
  imports = with inputs.self.modules.nixos; [
    helium
  ];

  environment.systemPackages = with pkgs; [
    trilium-desktop
    xournalpp
    scrcpy
    (obs-studio.override { browserSupport = false; })
    picard
    tigervnc
    open-scq30
    zapfast
    android-tools
    aria2
    ffmpeg
    tsukimi
    t3code-desktop
  ];

  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
}
