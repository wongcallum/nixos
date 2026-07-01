{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      tuigreet = inputs.tuigreet.packages.${pkgs.stdenv.hostPlatform.system}.tuigreet;
      sessions = config.services.displayManager.sessionData.desktops;
    in
    {
      programs.kdeconnect = {
        enable = true;
        # https://bugs.kde.org/show_bug.cgi?id=513536
        # mkForce to win over plasma6, which also sets this package.
        package = lib.mkForce (
          pkgs.kdePackages.kdeconnect-kde.overrideAttrs (old: {
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [
              (lib.cmakeBool "BLUETOOTH_ENABLED" false)
            ];
          })
        );
      };

      services.greetd = {
        enable = true;
        useTextGreeter = true;
        settings.default_session.command = "${lib.getExe tuigreet} --asterisks --time --remember --remember-session --sessions ${sessions}/share/wayland-sessions --xsessions ${sessions}/share/xsessions --cmd niri-session";
      };

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.greetd.kwallet = {
        enable = true;
        package = pkgs.kdePackages.kwallet-pam;
      };

      environment.systemPackages = [
        pkgs.adw-gtk3
        pkgs.qt6Packages.qt6ct
        pkgs.libsForQt5.qt5ct
      ];

      xdg.portal.enable = true;

      services = {
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };

        printing = {
          enable = true;
          drivers = with pkgs; [
            cups-filters
            cups-browsed
          ];
        };

        ipp-usb.enable = true;

        udisks2.enable = true;
        gvfs.enable = true;
      };
    };
}
