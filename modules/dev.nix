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
        jq
        ripgrep
        unzip
        nh

        git
        lazygit
        gh
        tea

        neovim
        tree-sitter

        nixd
        nil
        nixfmt
      ];

      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
      };
    };
}
