{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "xanh-mono";
  version = "0-unstable-2020-09-29";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchFromGitHub {
    owner = "yellow-type-foundry";
    repo = "xanhmono";
    rev = "5c0ceb816ffc1e8f79be71c82a43201395f3eca5";
    sha256 = "sha256-XM4Ee8BjaNw+wGzHQuWD9rcPPEBmHu/sk7lRBZ/PHHc=";
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/truetype fonts/ttf/*.ttf

    runHook postInstall
  '';
}
