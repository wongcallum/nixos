{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    coder
    (obs-studio.override { cudaSupport = true; })
    equibop
    feishin
    faugus-launcher
  ];
}
