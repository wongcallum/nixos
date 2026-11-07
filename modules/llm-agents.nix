{ inputs, ... }:
{
  flake.modules.nixos.base = {
    nixpkgs.overlays = [
      (final: _prev: {
        t3code =
          let
            agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
          in
          agents.t3code.override { providerPackages = [ agents.claude-code ]; };
        t3code-desktop =
          let
            unwrapped = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.t3code-desktop.override {
              inherit (final) t3code;
            };
          in
          final.symlinkJoin {
            inherit (unwrapped) name meta;
            paths = [ unwrapped ];
            nativeBuildInputs = [ final.makeBinaryWrapper ];
            # Matches the interactive shell, so setup scripts get wrapped in its syntax.
            postBuild = ''
              wrapProgram $out/bin/t3code-desktop --set SHELL ${final.lib.getExe final.fish}
            '';
          };
      })
    ];
  };
}
