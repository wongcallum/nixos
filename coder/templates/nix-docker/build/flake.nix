{
  description = "Tools provisioned into Coder workspaces";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  outputs =
    { nixpkgs, llm-agents, ... }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system}.default =
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        pkgs.buildEnv {
          name = "coder-tools";
          paths = [
            llm-agents.packages.${system}.codex
          ]
          ++ (with pkgs; [
            chezmoi
            zellij
            mise
            direnv
            git
            delta
            lazygit
            gh
            fish
            jq
            ripgrep
            wget
            neovim

            ghostty.terminfo
          ]);
        };
    };
}
