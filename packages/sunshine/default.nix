{
  buildNpmPackage,
  fetchFromGitHub,
  fetchzip,
  lib,
  qt6,
  sunshine,
  vulkan-loader,
}:
let
  version = "2026.906.222525";

  src = fetchFromGitHub {
    owner = "LizardByte";
    repo = "Sunshine";
    tag = "v${version}";
    hash = "sha256-2Ab8KSX/SY3OFeqhwgYmMX/HQdV/jcCpNAFOEdG3V8w=";
    fetchSubmodules = true;
  };

  # FFmpeg 9 requires NVENC API 13.1 and an NVIDIA 610+ driver. Keep the
  # prepared FFmpeg from the preceding build-deps release until nixpkgs ships a
  # compatible driver; it targets the NVENC API supported by the current 595.
  ffmpegPrebuilt = fetchzip {
    url = "https://github.com/LizardByte/build-deps/releases/download/v2026.516.30821/Linux-x86_64-ffmpeg.tar.gz";
    hash = "sha256-VT+4qP2FaizCoIBBbBkzbYw4YOvGhuBUoZxWL0IYVZo=";
  };
in
(sunshine.override { cudaSupport = true; }).overrideAttrs (
  finalAttrs: oldAttrs: {
    inherit version src;

    ui = buildNpmPackage {
      inherit src version;
      pname = "sunshine-ui";
      npmDepsHash = "sha256-w9/11m9PnwxuA9qJJH3JiGwperBSKNUGW2QAHFiejxo=";

      installPhase = ''
        runHook preInstall

        mkdir -p "$out"
        cp -a . "$out"/

        runHook postInstall
      '';
    };

    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ qt6.wrapQtAppsHook ];
    buildInputs = oldAttrs.buildInputs ++ [
      qt6.qtbase
      qt6.qtsvg
    ];

    cmakeFlags =
      builtins.filter (flag: !(lib.hasInfix "FFMPEG_PREPARED_BINARIES" flag)) oldAttrs.cmakeFlags
      ++ [ (lib.cmakeFeature "FFMPEG_PREPARED_BINARIES" "${ffmpegPrebuilt}") ];

    preBuild = ''
      cp -r ${finalAttrs.ui}/build ../
    '';

    dontWrapQtApps = true;
    postFixup = ''
      wrapProgram $out/bin/sunshine \
        "''${qtWrapperArgs[@]}" \
        --set LD_LIBRARY_PATH ${lib.makeLibraryPath [ vulkan-loader ]}
    '';
  }
)
