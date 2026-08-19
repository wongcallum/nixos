{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "2026.08.08.e6a2887";
in
stdenvNoCC.mkDerivation {
  pname = "phanpy";
  inherit version;

  src = fetchurl {
    url = "https://github.com/cheeaun/phanpy/releases/download/${version}/phanpy-dist.tar.gz";
    hash = "sha256-dTMfQ44hfrL+t7mUrf2D1LrTuT+CikgL3x7ONc49PQY=";
  };
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp -r . $out/
  '';

  meta = {
    description = "Minimalistic opinionated Mastodon web client";
    homepage = "https://phanpy.social";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
