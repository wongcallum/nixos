_: {
  flake.modules.nixos.fonts =
    { lib, pkgs, ... }:
    let
      comic-mono-nf = pkgs.callPackage ../packages/fonts/comic-mono-nf-v1 { };
      bitmap-fonts = pkgs.callPackage ../packages/fonts/personal-bitmap-fonts { };
      harmonyos-sans = pkgs.callPackage ../packages/fonts/harmonyos-sans { };
      chivo-mono = pkgs.callPackage ../packages/fonts/chivo-mono { };
      xanh-mono = pkgs.callPackage ../packages/fonts/xanh-mono { };

      # workaround: paper-mono-1-000
      paper-mono = pkgs.paper-mono.overrideAttrs (_: {
        version = "1.000";
        src = pkgs.fetchzip {
          url = "https://github.com/paper-design/paper-mono/releases/download/v1.000/paper-mono-v1.000.zip";
          hash = "sha256-h5yTJS+Oln2r4HcuHu3gjrw41udw/Uj/rmV/niPfaEg=";
        };
      });
    in
    {
      modules.fonts.enable = lib.mkDefault true;

      fonts = {
        fontDir.enable = true;
        enableGhostscriptFonts = true;
        packages = with pkgs; [
          # standard fonts
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          ibm-plex
          liberation_ttf
          inter
          harmonyos-sans

          # monospace fonts
          nerd-fonts.monaspace
          nerd-fonts.jetbrains-mono
          nerd-fonts.recursive-mono
          nerd-fonts.go-mono
          nerd-fonts.cousine
          nerd-fonts."m+"
          chivo-mono
          xanh-mono
          paper-mono
          comic-mono-nf
          ioskeley-mono.standard
          libertinus

          # bitmap fonts
          terminus_font
          bitmap-fonts
        ];
        fontconfig = {
          enable = true;
          allowBitmaps = true;

          defaultFonts = {
            monospace = [ "Ioskeley Mono" ];
            sansSerif = [ "Inter" ];
            serif = [ "Noto Serif" ];
          };
        };
      };
    };
}
