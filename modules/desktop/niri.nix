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

      # workaround: niri-3fg-drag
      systemd.user.services.niri.environment.LD_PRELOAD = "${
        pkgs.callPackage ../../packages/enable-3fg-drag { }
      }/lib/libenable-3fg-drag.so";

      # fix dolphin file associations
      # workaround: dolphin-applications-menu
      environment.etc."xdg/menus/applications.menu".source =
        "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

      # not sure if these are used
      fonts.packages = with pkgs; [
        material-symbols
        fira-code
      ];

      environment.systemPackages = with pkgs; [
        xwayland-satellite
        adwaita-icon-theme

        # for dms-quick-capture
        imagemagick
        img2pdf
        (tesseract.override { enableLanguages = [ "eng" ]; })
        zbar
      ];
    };
}
