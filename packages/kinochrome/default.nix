{
  lib,
  rustPlatform,
  fetchgit,
  makeWrapper,
  shaderc,
  ffmpeg,
  vulkan-loader,
  wayland,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
}:

let
  runtimeLibs = [
    vulkan-loader
    wayland
    libxkbcommon
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
rustPlatform.buildRustPackage {
  pname = "kinochrome";
  version = "0.1.0-unstable-2026-03-06";

  src = fetchgit {
    url = "https://git.sr.ht/~grego/kinochrome";
    rev = "0a950233a8dd31592c215e6fc1b6f6bd6c538a06";
    fetchSubmodules = true;
    hash = "sha256-vvP6URCl8CFGfFe8o229FUvQjtspnXQSnlStJ6qeA38=";
  };

  cargoHash = "sha256-qs+nBLalQ8n+S33dAY68ori4l9F+fn/QELPDs8iw5G4=";

  nativeBuildInputs = [
    shaderc # glslc
    makeWrapper
  ];

  postPatch = ''
    substituteInPlace src/main.rs \
      --replace-fail '"shaders/vert.spv"' "\"$out/share/kinochrome/shaders/vert.spv\"" \
      --replace-fail '"shaders/frag.spv"' "\"$out/share/kinochrome/shaders/frag.spv\"" \
      --replace-fail '"shaders/comp.spv"' "\"$out/share/kinochrome/shaders/comp.spv\"" \
      --replace-fail 'const RECIPE_DIR: &str = "recipes";' \
                     "const RECIPE_DIR: &str = \"$out/share/kinochrome/recipes\";"
    substituteInPlace src/import.rs \
      --replace-fail '"pixel_maps/{:x}_{}x{}.fpm"' \
                     "\"$out/share/kinochrome/pixel_maps/{:x}_{}x{}.fpm\""
  '';

  preBuild = ''
    make
  '';

  postInstall = ''
    mkdir -p $out/share/kinochrome
    cp -r pixel_maps recipes $out/share/kinochrome/
    install -Dm444 -t $out/share/kinochrome/shaders shaders/*.spv
  '';

  postFixup = ''
    wrapProgram $out/bin/kinochrome \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
  '';

  meta = {
    description = "GPU accelerated Magic Lantern raw video processor";
    homepage = "https://git.sr.ht/~grego/kinochrome";
    license = lib.licenses.agpl3Only;
    mainProgram = "kinochrome";
    platforms = lib.platforms.linux;
  };
}
