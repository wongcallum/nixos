{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  dbus,
  sqlite,
  wayland,
  libxkbcommon,
  libGL,
  fontconfig,
  freetype,
  libinput,
  expat,
  udev,
  vulkan-loader,
  cosmic-icons,
}:
rustPlatform.buildRustPackage {
  pname = "openscq30";
  version = "2.10.1";

  src = fetchFromGitHub {
    owner = "Oppzippy";
    repo = "OpenSCQ30";
    rev = "0dc9b2b0a98fb5ded4f1dcc38d18381112031014";
    hash = "sha256-YIUQ3bWj3CQl1iYpaOnGjM8oH5q9xhPtKDuXseat+fQ=";
  };

  cargoHash = "sha256-M+7YgmSxKuWIb7Y2d9HySePvUb6CeCHZdZTVnR7ED0Y=";
  cargoBuildFlags = [
    "--package"
    "openscq30-gui"
  ];
  doCheck = false;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    dbus
    sqlite
    wayland
    libxkbcommon
    libGL
    fontconfig
    freetype
    libinput
    expat
    udev
    vulkan-loader
  ];

  postInstall = ''
    wrapProgram "$out/bin/openscq30-gui" \
      --prefix XDG_DATA_DIRS : "${cosmic-icons}/share"
  '';

  meta = {
    description = "Control settings for Soundcore headphones and earbuds";
    homepage = "https://github.com/Oppzippy/OpenSCQ30";
    license = lib.licenses.gpl3Only;
    mainProgram = "openscq30-gui";
    platforms = lib.platforms.linux;
  };
}
