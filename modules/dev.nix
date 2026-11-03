{ inputs, ... }:
{
  flake.modules.nixos.dev =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        direnv
        nix-ld
        nix-output-monitor
        zoxide
      ];

      environment.systemPackages = with pkgs; [
        chezmoi
        mise
        devenv
        zellij
        jq
        ripgrep
        unzip
        nh

        git
        delta
        lazygit
        gh
        tea

        neovim
        tree-sitter

        nixd
        nil
        nixfmt
        lua-language-server
      ];

      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
      };
    };
}
