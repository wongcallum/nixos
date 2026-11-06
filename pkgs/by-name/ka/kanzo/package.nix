{
  lib,
  rustPlatform,
  fetchFromGitHub,
  gitMinimal,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "kanzo";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "emanuele-em";
    repo = "kanzo";
    tag = "v${finalAttrs.version}";
    hash = "sha256-66a6i7sOO1M1ZsLB6WRjCPhKCMCCIH2K+p8XnkfUznY=";
  };

  nativeCheckInputs = [ gitMinimal ];

  cargoHash = "sha256-40wOkEKsf5owShOL1OYL98NDAMDeJe1Y7GDRe8xBAU8=";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Kanban board and MCP server for you and your coding agents";
    homepage = "https://github.com/emanuele-em/kanzo";
    license = lib.licenses.agpl3Only;
    mainProgram = "kanzo";
  };
})
