{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "lobehub-desktop";
  version = "2.2.8";

  src = fetchurl {
    url = "https://github.com/lobehub/lobehub/releases/download/v${version}/LobeHub-${version}.AppImage";
    hash = "sha256-xpcdQWk4Zkgv5k5x0iuyQ20GCcsLxx9+TPHl5FUpLHc=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/lobehub-desktop.desktop \
      -t $out/share/applications
    substituteInPlace $out/share/applications/lobehub-desktop.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=lobehub-desktop --no-sandbox %U'
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/514x514/apps/lobehub-desktop.png \
      $out/share/pixmaps/lobehub-desktop.png
  '';

  meta = {
    description = "LobeHub desktop application, an open-source AI chat client";
    homepage = "https://lobehub.com";
    downloadPage = "https://github.com/lobehub/lobehub/releases";
    # Apache-2.0 with additional commercial conditions; not OSI-free but
    # freely redistributable for non-commercial / unmodified use.
    license = {
      shortName = "LobeHub Community License";
      fullName = "LobeHub Community License (based on Apache-2.0)";
      url = "https://github.com/lobehub/lobehub/blob/master/LICENSE";
      free = false;
      redistributable = true;
    };
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "lobehub-desktop";
  };
}
