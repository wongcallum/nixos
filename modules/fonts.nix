{
  flake.modules.nixos.fonts =
    { lib, pkgs, ... }:
    let
      comic-mono-nf = pkgs.callPackage ../packages/fonts/comic-mono-nf { };
      ioskeley-mono = pkgs.callPackage ../packages/fonts/ioskeley-mono { };
      bitmap-fonts = pkgs.callPackage ../packages/fonts/personal-bitmap-fonts { };
      ibm-olympiad = pkgs.callPackage ../packages/fonts/ibm-olympiad-ttf { };
      harmonyos-sans = pkgs.callPackage ../packages/fonts/harmonyos-sans { };
    in
    {
      modules.fonts.enable = lib.mkDefault true;

      fonts = {
        fontDir.enable = true;
        enableGhostscriptFonts = true;
        packages = with pkgs; [
          # standard fonts
          noto-fonts
          cantarell-fonts
          liberation_ttf
          inter
          harmonyos-sans

          # cjk support
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif

          # monospace fonts
          monaspace
          nerd-fonts.jetbrains-mono
          nerd-fonts.recursive-mono
          comic-mono-nf
          ioskeley-mono

          # bitmap fonts
          terminus_font
          bitmap-fonts
          ibm-olympiad
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
