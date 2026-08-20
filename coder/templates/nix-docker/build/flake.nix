{
  description = "Tools provisioned into Coder workspaces";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    {
      packages.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.buildEnv {
          name = "coder-tools";
          paths = with pkgs; [
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
          ];
        };
    };
}
