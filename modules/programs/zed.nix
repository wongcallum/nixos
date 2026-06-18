{ inputs, ... }:
{
  flake.modules.nixos.zed =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.zed.packages.${pkgs.system}.default
      ];
    };
}
