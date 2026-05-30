{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "ioskeley-mono";
  version = "2025.10.09-6";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchzip {
    url = "https://github.com/ahatem/IoskeleyMono/releases/download/${version}/IoskeleyMono-TTF-Hinted.zip";
    sha256 = "sha256-K1JpF4PLA81o9OHMDbmWBd2otbqc2XpB9J7/vHn5718=";
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/truetype *.ttf

    runHook postInstall
  '';
}
