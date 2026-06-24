{
  flake.modules.nixos.desktop =
    { pkgs, lib, ... }:
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

        kdeconnect = {
          enable = true;
          # https://bugs.kde.org/show_bug.cgi?id=513536
          package = pkgs.kdePackages.kdeconnect-kde.overrideAttrs (old: {
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [
              (lib.cmakeBool "BLUETOOTH_ENABLED" false)
            ];
          });
        };
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
        pkgs.libsForQt5.qt5ct
      ];

      xdg.portal.enable = true;

      services = {
        printing.enable = true;
        udisks2.enable = true;
        gvfs.enable = true;
      };
    };
}
