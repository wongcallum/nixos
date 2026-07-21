{ inputs, ... }:
{
  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      programs = {
        niri.enable = true;

        dank-material-shell = {
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

      environment.systemPackages = with pkgs; [
        xwayland-satellite

        # for dms-quick-capture
        imagemagick
        img2pdf
        tesseract
        zbar
      ];
    };
}
