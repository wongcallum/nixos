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
  nix-update-script,
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
  version = "0.1.0-unstable-2026-09-06";

  src = fetchgit {
    url = "https://git.sr.ht/~grego/kinochrome";
    rev = "5c29e42cdd07cd2e09a503a2936926be94535aad";
    fetchSubmodules = true;
    hash = "sha256-S55B9vZnPrYGBk81qhsyGF+rrvtHPE6RVSwKaBmaQDQ=";
  };

  cargoHash = "sha256-Dtn2cWiMaEH8rtAXfycjh71Pk1tIcj450apxD1VYuHU=";

  nativeBuildInputs = [
    shaderc # glslc
    makeWrapper
  ];

  postPatch = ''
    substituteInPlace src/main.rs \
      --replace-fail '"shaders/vert.spv"' "\"$out/share/kinochrome/shaders/vert.spv\"" \
      --replace-fail '"shaders/frag.spv"' "\"$out/share/kinochrome/shaders/frag.spv\"" \
      --replace-fail '"shaders/comp.spv"' "\"$out/share/kinochrome/shaders/comp.spv\"" \
      --replace-fail '"shaders/lut.spv"' "\"$out/share/kinochrome/shaders/lut.spv\"" \
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

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  meta = {
    description = "GPU accelerated Magic Lantern raw video processor";
    homepage = "https://git.sr.ht/~grego/kinochrome";
    license = lib.licenses.agpl3Only;
    mainProgram = "kinochrome";
    platforms = lib.platforms.linux;
  };
}
