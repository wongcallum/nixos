{
  perSystem =
    { pkgs, ... }:
    {
      packages.coder-tools = pkgs.buildEnv {
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
