{ inputs, ... }:
{
  flake.modules.nixos.ghostty =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.ghostty.packages.${pkgs.system}.default
      ];
    };
}
