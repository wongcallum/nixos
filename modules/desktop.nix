{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    { ... }:
    {
      imports = [
        inputs.dms.nixosModules.dank-material-shell
      ];

      programs.dank-material-shell = {
        enable = true;
        systemd = {
          enable = true;
          restartIfChanged = true;
        };
      };

      programs.niri.enable = true;

      xdg.portal.enable = true;

      programs.kdeconnect.enable = true;

      services.printing.enable = true;
      services.udisks2.enable = true;
    };
}
