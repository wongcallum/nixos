{ inputs, ... }:

{
  perSystem =
    { system, ... }:
    {
      packages.ghostty = inputs.ghostty.packages.${system}.default;
    };

  flake.modules.nixos.ghostty =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
