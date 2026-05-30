{ inputs, ... }:
{
  flake.modules.nixos.desktop =
    { ... }:
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

      xdg.portal.enable = true;

      programs.kdeconnect.enable = true;

      services.printing.enable = true;
      services.udisks2.enable = true;
    };
}
