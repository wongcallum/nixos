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
  fetchpatch,
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

  # workaround: askama-config-path-symlink
  # askama_derive mangles askama.toml's path when the crate is reached
  # through a symlink, as every crate in crane's vendor directory is
  cargoVendorDir = craneLib.vendorCargoDeps {
    src = source;
    overrideVendorCargoPackage =
      p: drv:
      if p.name == "askama_derive" then
        drv.overrideAttrs (old: {
          # the commits of askama PR 744
          patches = (old.patches or [ ]) ++ [
            (fetchpatch {
              url = "https://github.com/askama-rs/askama/commit/80bfe085108e642e47715a764292c66ad0c2babb.patch";
              relative = "askama_derive";
              hash = "sha256-jGSvr+R6xmaEW6/20R29+z1aNceYFXazuCEEgD/nABI=";
            })
            (fetchpatch {
              url = "https://github.com/askama-rs/askama/commit/711b4202640c93d0b75bcc137f8be1bf2f46c496.patch";
              relative = "askama_derive";
              hash = "sha256-2ZCaitfKZMcCj6tSmc9DFHMosQkhuJ50XzjIigo8y+E=";
            })
          ];
        })
      else
        drv;
  };

  commonArgs = {
    src = source;
    pname = "openscq30";
    inherit cargoVendorDir;
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
    version = "2.13.0";
    pname = "openscq30-cli";
    cargoExtraArgs = "--package openscq30-cli";
    buildInputs = commonBuildInputs;
    meta.mainProgram = "openscq30";
  };

  openscq30-gui = mkPackage {
    inherit cargoArtifacts;
    version = "2.13.0";
    pname = "openscq30-gui";
    cargoExtraArgs = "--package openscq30-gui";
    meta.mainProgram = "openscq30-gui";
    postInstall = ''
      wrapProgram "$out/bin/openscq30-gui" \
        --prefix XDG_DATA_DIRS : "${cosmic-icons}/share"
    '';
  };
}
