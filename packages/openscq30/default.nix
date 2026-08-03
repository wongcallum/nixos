{
  lib,
  craneLib,
  src,
  pkg-config,
  makeWrapper,
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

let
  # Keep the source files embedded by the CLI and GUI builds. The workspace
  # contains resources outside the files selected by crane's Cargo filter.
  source = lib.cleanSourceWith {
    src = lib.cleanSource src;
    filter =
      path: type:
      (craneLib.filterCargoSources path type)
      || lib.hasSuffix ".ftl" path
      || lib.hasSuffix ".sql" path
      || lib.hasSuffix ".svg" path
      || lib.hasSuffix ".png" path
      || lib.hasSuffix ".ico" path
      || lib.hasSuffix ".desktop" path
      || lib.hasSuffix ".metainfo.xml" path;
  };

  commonBuildInputs = [
    dbus
    sqlite
  ];

  guiOnlyBuildInputs = [
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

  commonArgs = {
    src = source;
    pname = "openscq30";
    nativeBuildInputs = [
      pkg-config
      makeWrapper
    ];
    buildInputs = commonBuildInputs ++ guiOnlyBuildInputs;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  mkPackage = args: craneLib.buildPackage (lib.recursiveUpdate commonArgs args);
in
{
  openscq30-cli = mkPackage {
    inherit cargoArtifacts;
    version = "2.10.1";
    pname = "openscq30-cli";
    cargoExtraArgs = "--package openscq30-cli";
    buildInputs = commonBuildInputs;
    meta.mainProgram = "openscq30";
  };

  openscq30-gui = mkPackage {
    inherit cargoArtifacts;
    version = "2.10.1";
    pname = "openscq30-gui";
    cargoExtraArgs = "--package openscq30-gui";
    meta.mainProgram = "openscq30-gui";
    postInstall = ''
      wrapProgram "$out/bin/openscq30-gui" \
        --prefix XDG_DATA_DIRS : "${cosmic-icons}/share"
    '';
  };
}
