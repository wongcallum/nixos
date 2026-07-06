{
  flake.modules.nixos.console-font =
    { pkgs, ... }:
    let
      bitmap-fonts = pkgs.callPackage ../packages/fonts/personal-bitmap-fonts { };
    in
    {
      console = {
        earlySetup = true;
        font = "${pkgs.runCommand "BmPlus_ToshibaSat_8x16.psf"
          {
            nativeBuildInputs = [
              pkgs.fontforge
              pkgs.bdf2psf
            ];
          }
          ''
            export HOME="$TMPDIR"
            fontforge -lang=py -c \
              'import fontforge, sys; fontforge.open(sys.argv[1]).generate("font.bdf")' \
              ${bitmap-fonts}/share/fonts/misc/BmPlus_ToshibaSat_8x16.otb

            sets=${pkgs.bdf2psf}/share/bdf2psf

            # systemd status bullet character, claude thinks we need it
            echo 'U+25CF' > extra.set

            # fontforge suffixes the bdf with the strike's pixel size (font-16.bdf)
            bdf2psf --fb font-*.bdf \
              "$sets/standard.equivalents" \
              "$sets/ascii.set+$sets/linux.set+$PWD/extra.set+$sets/useful.set" \
              512 "$out"
          ''
        }";
      };
    };
}
