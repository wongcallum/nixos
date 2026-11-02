{
  lib,
  stdenvNoCC,
  buildFHSEnv,
  glibc,
  fetchurl,
  dpkg,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libGL,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  zlib,
}:

let
  pname = "chainner";
  version = "0.25.1";

  src = fetchurl {
    url = "https://github.com/chaiNNer-org/chaiNNer/releases/download/v${version}/chaiNNer_${version}-x64-linux-debian.deb";
    hash = "sha256-6XqfdKlTRuLrPxpMzfYz4KT6U6r2A4VMUvUKCqnkNlg=";
  };

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libdrm
    libgbm
    libnotify
    libpulseaudio
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    nspr
    nss
    pango
    systemd
    wayland
    zlib
  ];

  # unpatched: autoPatchelf'd builds crash with "Zygote could not fork"
  chainner-unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version src;

    nativeBuildInputs = [ dpkg ];

    dontPatchELF = true;
    dontStrip = true;
    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      dpkg --fsys-tarfile $src | tar --extract
      rm -rf usr/share/lintian

      mkdir -p $out
      mv usr/* $out
      rm $out/bin/chainner

      mkdir -p $out/share/icons/hicolor/256x256/apps
      mv $out/share/pixmaps/chainner.png $out/share/icons/hicolor/256x256/apps/chainner.png
      rmdir $out/share/pixmaps

      runHook postInstall
    '';
  };
in
buildFHSEnv {
  inherit pname version;

  # for the numpy in the CPython chaiNNer downloads on first run
  targetPkgs = _pkgs: runtimeLibs ++ [ glibc ];

  # the store has no setuid chrome-sandbox
  runScript = "${chainner-unwrapped}/lib/chainner/chainner --no-sandbox";

  # Electron detaches from the terminal on purpose
  dieWithParent = false;

  extraInstallCommands = ''
    mkdir -p $out/share
    ln -s ${chainner-unwrapped}/share/applications $out/share/applications
    ln -s ${chainner-unwrapped}/share/icons $out/share/icons
  '';

  meta = {
    description = "Node-based image processing GUI, born as an AI upscaling application";
    homepage = "https://chainner.app";
    downloadPage = "https://github.com/chaiNNer-org/chaiNNer/releases";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chainner";
  };
}
