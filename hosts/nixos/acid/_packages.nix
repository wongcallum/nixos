{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    coder
    (obs-studio.override {
      cudaSupport = true;
      browserSupport = false;
    })
    equibop
    feishin
    faugus-launcher
  ];
}
