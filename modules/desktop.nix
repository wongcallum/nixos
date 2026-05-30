{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      imports = [
        inputs.dms.nixosModules.dank-material-shell
        inputs.dms.nixosModules.greeter
      ];

      programs = {
        dank-material-shell = {
          enable = true;
          systemd = {
            enable = true;
            restartIfChanged = true;
          };
          greeter = {
            enable = true;
            compositor.name = "niri";
            configHome = "/home/callum";
          };
        };

        niri.enable = true;

        kdeconnect.enable = true;
      };

      environment.systemPackages = [
        pkgs.adw-gtk3
        pkgs.xwayland-satellite
        pkgs.qt6Packages.qt6ct
      ];

      xdg.portal.enable = true;

      services = {
        printing.enable = true;
        udisks2.enable = true;
        gvfs.enable = true;
      };
    };
}
