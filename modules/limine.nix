{
  flake.modules.nixos.limine =
    { pkgs, config, ... }:
    let
      aixoid9-f20 = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/viler-int10h/vga-text-mode-fonts/ab3965599eb3d0de9834fa9c26942b4e4843a42b/FONTS/AIXOID9.F20";
        hash = "sha256-ymzd10iPHaNTW1Idem3dOcU5+UCHGZs3CfztDJqYSho=";
      };
    in
    {
      boot.loader = {
        timeout = 10;
        limine = {
          enable = true;

          additionalFiles."fonts/AIXOID9.F20" = aixoid9-f20;
          extraConfig = ''
            term_font: boot():/limine/fonts/AIXOID9.F20
            term_font_size: 8x20
          '';

          # from https://github.com/diegons490/cachyos-limine-theme
          style = {
            interface.branding = config.networking.hostName;
            wallpapers = [ pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt.gnomeFilePath ];
            graphicalTerminal = {
              palette = "1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4";
              brightPalette = "585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4";
              background = "ffffffff";
              foreground = "cdd6f4";
              brightBackground = "ffffffff";
              brightForeground = "cdd6f4";
            };
          };
        };
      };
    };
}
