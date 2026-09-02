{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "chivo-mono";
  version = "0-unstable-2022-11-10";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchFromGitHub {
    owner = "Omnibus-Type";
    repo = "Chivo";
    rev = "dc61c468d79781eb5183426e88e844af16cdc3e5";
    sha256 = "sha256-GpOhwDzTVk1gMwozjIqlOnaoleS9jTSzVMjzb6mzuj0=";
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/truetype "fonts/Chivo Mono/ttf"/*.ttf

    runHook postInstall
  '';
}
