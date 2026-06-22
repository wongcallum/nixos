{ inputs, ... }:
{
  flake.modules.nixos.zed =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.zed.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
