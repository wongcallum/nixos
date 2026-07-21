{ inputs, ... }:
{
  flake.modules.nixos.trilium-desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.trilium-next.packages.${pkgs.stdenv.hostPlatform.system}.desktop
      ];
    };
}
