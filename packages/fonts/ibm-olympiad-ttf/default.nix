{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "personal-bitmap-fonts";
  version = "1.0";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  # these fonts seem to be what "AIXOID9x20" is based on
  src = fetchzip {
    stripRoot = false;
    url = "http://int10h.org/filez/Olympiad_Fonts_v${version}.zip";
    sha256 = "sha256-2duBwdvLntFKzPE2mH9op9Hu1/0wsvQIkKAstPuJJco=";
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/misc *.ttf

    runHook postInstall
  '';
}
