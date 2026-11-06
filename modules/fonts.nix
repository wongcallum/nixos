{
  flake.modules.nixos.fonts =
    { lib, pkgs, ... }:
    {
      modules.fonts.enable = lib.mkDefault true;

      fonts = {
        fontDir.enable = true;
        enableGhostscriptFonts = true;
        packages = with pkgs; [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          ibm-plex
          liberation_ttf
          inter
          harmonyos-sans

          nerd-fonts.monaspace
          nerd-fonts.jetbrains-mono
          nerd-fonts.recursive-mono
          nerd-fonts.go-mono
          nerd-fonts.cousine
          nerd-fonts."m+"
          chivo-mono
          xanh-mono
          paper-mono
          comic-mono-nf-v1
          ioskeley-mono.standard
          libertinus

          terminus_font
          personal-bitmap-fonts
        ];
        fontconfig = {
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
