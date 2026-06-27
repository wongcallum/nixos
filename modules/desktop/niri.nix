{
  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      programs = {
        niri.enable = true;

        dms-shell = {
          enable = true;
          # in niri config: `spawn-at-startup "dms" "run"`
          systemd.enable = false;
        };
      };

      # not sure if these are used
      fonts.packages = with pkgs; [
        material-symbols
        fira-code
      ];

      environment.systemPackages = [ pkgs.xwayland-satellite ];
    };
}
