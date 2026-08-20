{ inputs, pkgs, ... }:
let
  hermes-desktop = pkgs.callPackage ../../../packages/hermes-desktop {
    hermesSrc = inputs.hermes-agent;
  };
in
{
  environment.systemPackages = with pkgs; [
    coder
    (obs-studio.override { cudaSupport = true; })
    equibop
    feishin
    faugus-launcher
    hermes-desktop
  ];
}
