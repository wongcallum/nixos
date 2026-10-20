{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = inputs.unstable.legacyPackages.${system};
    in
    {
      packages.coder-tools = pkgs.buildEnv {
        name = "coder-tools";
        paths = with pkgs; [
          chezmoi
          zellij
          mise
          direnv
          git
          lazygit
          gh
          fish
          ripgrep
          neovim
          openssh
          ghostty.terminfo
        ];
      };
    };
}
