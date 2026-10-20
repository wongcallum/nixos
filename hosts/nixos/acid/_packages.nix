{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    (obs-studio.override {
      cudaSupport = true;
      browserSupport = false;
    })
  ];
}
