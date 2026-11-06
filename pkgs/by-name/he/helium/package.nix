# MIT License
#
# Copyright (c) 2025 weegs710
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

{
  lib,
  stdenv,
  fetchurl,
  writeText,
  writeShellScript,
  buildFHSEnv,
  makeWrapper,
  autoPatchelfHook,
  widevine-cdm,
  gtk3,
  nss,
  nspr,
  alsa-lib,
  cups,
  libdrm,
  mesa,
  expat,
  libxkbcommon,
  pango,
  cairo,
  at-spi2-atk,
  at-spi2-core,
  dbus,
  libva,
  libGL,
  nix-update-script,
}:
let
  version = "0.14.8.2";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64_linux.tar.xz";
    sha256 = "sha256-3XUwBw9sSQgPjTVX3oBGwK9PQXgN5J+ktdICey67wAE=";
  };

  widevineConfig = writeText "latest-component-updated-widevine-cdm" (
    builtins.toJSON {
      Path = "${widevine-cdm}/share/google/chrome/WidevineCdm";
    }
  );

  heliumPkg = stdenv.mkDerivation rec {
    pname = "helium";
    inherit version src;

    nativeBuildInputs = [
      makeWrapper
      autoPatchelfHook
    ];

    buildInputs = [
      stdenv.cc.cc.lib
      gtk3
      nss
      nspr
      alsa-lib
      cups
      libdrm
      mesa
      expat
      libxkbcommon
      pango
      cairo
      at-spi2-atk
      at-spi2-core
      dbus
      libva
      libGL
    ];

    # helium ships Qt shim stubs that autoPatchelf cannot satisfy; absence is intentional
    autoPatchelfIgnoreMissingDeps = [
      "libQt5Core.so.5"
      "libQt5Gui.so.5"
      "libQt5Widgets.so.5"
      "libQt6Core.so.6"
      "libQt6Gui.so.6"
      "libQt6Widgets.so.6"
    ];

    sourceRoot = "helium-${version}-x86_64_linux";

    installPhase = ''
      mkdir -p $out/opt/helium $out/bin

      cp -r . $out/opt/helium/
      chmod +x $out/opt/helium/helium

      makeWrapper $out/opt/helium/helium $out/bin/helium

      mkdir -p $out/share/applications
      cp $out/opt/helium/helium.desktop $out/share/applications/

      for size in 16 32 48 64 128 256; do
        mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
        if [ -f $out/opt/helium/product_logo_''${size}.png ]; then
          cp $out/opt/helium/product_logo_''${size}.png \
             $out/share/icons/hicolor/''${size}x''${size}/apps/helium.png
        fi
      done
    '';

    meta = {
      description = "Private, fast, and honest web browser";
      homepage = "https://helium.computer/";
      license = lib.licenses.gpl3Plus;
      platforms = [ "x86_64-linux" ];
    };
  };

  # --policy-dir and user-flags only fire once those config paths exist
  heliumWrapper = writeShellScript "helium-wrapper" ''
    USER_DATA_DIR=""
    for arg in "$@"; do
      if [[ "$arg" == --user-data-dir=* ]]; then
        USER_DATA_DIR="''${arg#*=}"
        break
      fi
    done

    if [ -z "$USER_DATA_DIR" ]; then
      USER_DATA_DIR="$HOME/.config/net.imput.helium"
    fi

    mkdir -p "$USER_DATA_DIR/WidevineCdm"
    cp ${widevineConfig} "$USER_DATA_DIR/WidevineCdm/latest-component-updated-widevine-cdm"
    chmod u+w "$USER_DATA_DIR/WidevineCdm/latest-component-updated-widevine-cdm"

    POLICY_FLAGS=""
    if [ -d "$HOME/.config/net.imput.helium/policies" ]; then
      POLICY_FLAGS="--policy-dir=$HOME/.config/net.imput.helium/policies"
    fi

    USER_FLAGS=""
    if [ -f "$HOME/.config/net.imput.helium/user-flags" ]; then
      USER_FLAGS=$(cat "$HOME/.config/net.imput.helium/user-flags")
    fi

    exec ${heliumPkg}/bin/helium $POLICY_FLAGS $USER_FLAGS "$@"
  '';

  wrappedHelium = buildFHSEnv {
    pname = "helium";
    inherit version;
    targetPkgs = _pkgs: [
      heliumPkg
      mesa
      libGL
      libdrm
      libva
    ];
    runScript = heliumWrapper;
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${heliumPkg}/share/applications/helium.desktop $out/share/applications/

      for size in 16 32 48 64 128 256; do
        mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
        if [ -f ${heliumPkg}/share/icons/hicolor/''${size}x''${size}/apps/helium.png ]; then
          cp ${heliumPkg}/share/icons/hicolor/''${size}x''${size}/apps/helium.png \
             $out/share/icons/hicolor/''${size}x''${size}/apps/
        fi
      done
    '';
    passthru = {
      inherit src;
      updateScript = nix-update-script { };
    };
    meta = heliumPkg.meta // {
      mainProgram = "helium";
      description = "Helium browser with Widevine DRM";
    };
  };
in
wrappedHelium
