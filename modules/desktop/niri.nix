{
  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      programs = {
        niri.enable = true;

        dux-shell = {
          enable = true;
          # The niri config starts it with `spawn-at-startup "dms" "run"`.
          systemd.enable = false;
        };
      };

      # The DMS flake's module enabled these; nixpkgs' leaves them to us.
      services.geoclue2.enable = true;

      # workaround: niri-3fg-drag
      systemd.user.services.niri.environment.LD_PRELOAD =
        "${pkgs.enable-3fg-drag}/lib/libenable-3fg-drag.so";

      fonts.packages = with pkgs; [
        material-symbols
        fira-code
      ];

      environment.systemPackages = with pkgs; [
        xwayland-satellite
        adwaita-icon-theme
        khal

        # for dms-quick-capture
        imagemagick
        img2pdf
        (tesseract.override { enableLanguages = [ "eng" ]; })
        zbar
      ];
    };
}
