{
  lib,
  stdenv,
  pkg-config,
  libinput,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "enable-3fg-drag";
  version = "unstable-2026-07-10";

  src = fetchFromGitHub {
    owner = "joaodriessen";
    repo = "enable-3fg-drag";
    rev = "09e9ca763eca05c33a183c7a6cf582bdd77dbbb1";
    hash = "sha256-mC1nHXCRHfZ0JYs2J/gBlqpYvReUHfgAQWETb48DMaw=";
  };

  nativeBuildInputs = [
    pkg-config
    libinput.dev
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 libenable-3fg-drag.so -t $out/lib
    runHook postInstall
  '';

  meta = {
    description = "LD_PRELOAD shim enabling libinput three-finger drag (macOS-style) in Wayland compositors";
    homepage = "https://github.com/joaodriessen/enable-3fg-drag";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
