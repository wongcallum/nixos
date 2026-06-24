{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "ioskeley-mono";
  version = "v2.0.0";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchzip {
    url = "https://github.com/ahatem/IoskeleyMono/releases/download/${version}/IoskeleyMono.zip";
    sha256 = "sha256-EJDlA18XZPq7vhtpw/74n5s1NmTy0/DLu2oYB7OuvbA=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall

    install -D -m444 -t $out/share/fonts/truetype Normal/Hinted/*.ttf

    runHook postInstall
  '';
}
