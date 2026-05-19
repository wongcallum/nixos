{
  flake.modules.nixos.desktop = {
    programs.niri.enable = true;

    xdg.portal.enable = true;

    programs.kdeconnect.enable = true;

    services.printing.enable = true;
    services.udisks2.enable = true;
  };
}
