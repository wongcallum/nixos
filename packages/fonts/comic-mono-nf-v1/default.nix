{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "comic-mono-nf-v1";
  version = "1";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchFromGitHub {
    owner = "xtevenx";
    repo = "ComicMonoNF";
    rev = "c1de10df975e728dcef6bf03d3a71d44ac84f3b8";
    sha256 = "sha256-yDynyU4hCo6jEOQOHR3Pc7AOJR5naU22FM/IwKy+Adw=";
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/truetype v${version}/*.ttf

    runHook postInstall
  '';
}
