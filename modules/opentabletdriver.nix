{
  flake.modules.nixos.opentabletdriver = {
    hardware.opentabletdriver.enable = true;
    hardware.uinput.enable = true;

    # crashes if service starts before DISPLAY/WAYLAND_DISPLAY are set
    systemd.user.services.opentabletdriver.after = [ "graphical-session.target" ];
  };
}
