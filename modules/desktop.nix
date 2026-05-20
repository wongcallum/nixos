{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      programs.hyprland = {
        enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };

      environment.systemPackages = [
        inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-shell
        inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-cli
      ];
  
      xdg.portal.enable = true;
  
      programs.kdeconnect.enable = true;
  
      services.printing.enable = true;
      services.udisks2.enable = true;
    };
}
