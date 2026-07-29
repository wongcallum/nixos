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

      # fix dolphin file associations
      # https://github.com/NixOS/nixpkgs/issues/409986
      environment.etc."xdg/menus/applications.menu".source =
        "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

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
