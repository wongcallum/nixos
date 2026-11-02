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
          inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.t3code-desktop.override
            {
              inherit (final) t3code;
            };
      })
    ];
  };
}
