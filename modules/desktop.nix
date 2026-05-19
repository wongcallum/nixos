{
  flake.modules.nixos.desktop = {
    programs.hyprland.enable = true;

    xdg.portal.enable = true;

    programs.kdeconnect.enable = true;

    services.printing.enable = true;
    services.udisks2.enable = true;
  };
}
