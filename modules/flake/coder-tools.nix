{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.unstable { inherit system; };
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
