{
  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      programs = {
        dms-shell = {
          enable = true;
          systemd = {
            enable = true;
            restartIfChanged = true;
          };
        };

        niri.enable = true;

        kdeconnect.enable = true;
      };

      services.displayManager.dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = "/home/callum";
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
