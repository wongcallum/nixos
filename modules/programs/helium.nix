{ inputs, ... }:
{
  flake.modules.nixos.helium =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.weegspkgs.packages.${pkgs.stdenv.hostPlatform.system}.helium
      ];
    };
}
