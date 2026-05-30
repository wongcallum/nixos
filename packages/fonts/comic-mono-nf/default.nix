{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "comic-mono-nf";
  version = "1";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchFromGitHub {
    owner = "xtevenx";
    repo = "ComicMonoNF";
    rev = "master";
    sha256 = "sha256-yDynyU4hCo6jEOQOHR3Pc7AOJR5naU22FM/IwKy+Adw=";
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/truetype v${version}/*.ttf

    runHook postInstall
  '';
}
