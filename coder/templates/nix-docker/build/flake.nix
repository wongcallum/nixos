{
  description = "Tools provisioned into Coder workspaces";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
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
          paths = with pkgs; [

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
            openssh

            ghostty.terminfo

          ];
        };
    };
}
