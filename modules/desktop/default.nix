{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = with inputs.self.modules.nixos; [
        audio
        niri
        fonts
        nix-ld
        direnv
        console-font
        zram
        tailscale
      ];

      programs.kdeconnect = {
        enable = true;
        # workaround: kdeconnect-no-bluetooth
        # mkForce to win over plasma6, which also sets this package.
        package = lib.mkForce (
          pkgs.kdePackages.kdeconnect-kde.overrideAttrs (old: {
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [
              (lib.cmakeBool "BLUETOOTH_ENABLED" false)
            ];
          })
        );
      };

      security.pam.services.greetd.kwallet = {
        enable = true;
        package = pkgs.kdePackages.kwallet-pam;
      };

      environment.systemPackages = [
        pkgs.adw-gtk3
        pkgs.qt6Packages.qt6ct
        pkgs.libsForQt5.qt5ct
      ];

      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
      };

      xdg.portal.enable = true;

      services = {
        displayManager.defaultSession = "niri";

        displayManager.dms-greeter = {
          enable = true;
          compositor.name = "niri";
          # keep the greeter's theme/wallpaper in sync with my DMS config
          configHome = config.users.users.callum.home;
        };

        gnome.gnome-keyring.enable = true;

        speechd.enable = false;

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
            fflinuxprint
          ];
        };

        ipp-usb.enable = true;

        udisks2.enable = true;
        gvfs.enable = true;
      };
    };
}
