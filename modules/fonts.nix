_: {
  flake.modules.nixos.fonts =
    { lib, pkgs, ... }:
    let
      comic-mono-nf = pkgs.callPackage ../packages/fonts/comic-mono-nf-v1 { };
      ioskeley-mono = pkgs.callPackage ../packages/fonts/ioskeley-mono { };
      bitmap-fonts = pkgs.callPackage ../packages/fonts/personal-bitmap-fonts { };
      harmonyos-sans = pkgs.callPackage ../packages/fonts/harmonyos-sans { };
      chivo-mono = pkgs.callPackage ../packages/fonts/chivo-mono { };
      xanh-mono = pkgs.callPackage ../packages/fonts/xanh-mono { };
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
          comic-mono-nf
          ioskeley-mono
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
