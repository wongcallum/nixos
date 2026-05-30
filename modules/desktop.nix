{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      imports = [
        inputs.dms.nixosModules.dank-material-shell
        inputs.dms.nixosModules.greeter
      ];

      programs.dank-material-shell = {
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

      programs.niri.enable = true;

      environment.systemPackages = [
        pkgs.adw-gtk3
        pkgs.xwayland-satellite
        pkgs.qt6Packages.qt6ct
      ];

      xdg.portal.enable = true;

      programs.kdeconnect.enable = true;

      services.printing.enable = true;
      services.udisks2.enable = true;
      services.gvfs.enable = true;
    };
}
