{
  flake.modules.nixos.hackneyed-cursors =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.hackneyed ];

      # Set system-wide so greetd's PAM session exports it into niri-session,
      # which is then imported into the user systemd/dbus environment and picked
      # up by Wayland and GTK clients as the default cursor.
      environment.sessionVariables = {
        XCURSOR_THEME = "Hackneyed";
        XCURSOR_SIZE = "24";
      };
    };
}
