{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  dbus,
  libGL,
  libglvnd,
  wayland,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrender,
}:

let
  # for egui/winit
  runtimeLibs = [
    dbus
    libGL
    libglvnd
    wayland
    libxkbcommon
    libx11
    libxcursor
    libxi
    libxrender
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "zapfast";
  version = "0.18.2";

  src = fetchurl {
    url = "https://github.com/crmne/zapfast/releases/download/v${finalAttrs.version}/zapfast-v${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-7DuniQ7oxd1TVK/Wal11J18Jmtb1IXJZRz81iTvwCRo=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    stdenv.cc.cc.lib
  ];

  # zapfast-portable.txt is deliberately not installed: beside the binary it
  # enables the in-app self-updater, which can't write to the nix store
  installPhase = ''
    runHook preInstall

    install -Dm755 zapfast -t $out/bin
    install -Dm444 packaging/applications/zapfast.desktop -t $out/share/applications
    install -Dm444 packaging/icons/zapfast.svg -t $out/share/icons/hicolor/scalable/apps

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/zapfast \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
  '';

  meta = {
    description = "Fast, lightweight native WhatsApp client";
    homepage = "https://zapfast.rocks";
    downloadPage = "https://github.com/crmne/zapfast/releases";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "zapfast";
  };
})
