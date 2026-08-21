{
  description = "Tools provisioned into Coder workspaces";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  # Deliberately not following nixpkgs: llm-agents.nix publishes binaries only
  # for its own nixpkgs revision, and codex is a from-source Rust build that a
  # workspace container has no business doing itself.
  inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  outputs =
    { nixpkgs, llm-agents, ... }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.buildEnv {
          name = "coder-tools";
          paths = [
            llm-agents.packages.${system}.codex
          ]
          ++ (with pkgs; [
            chezmoi
            zellij
            devenv
            mise
            direnv
            git
            delta
            lazygit
            gh
            nushell
            jq
            ripgrep
            wget
            neovim
          ]);
        };
    };
}
