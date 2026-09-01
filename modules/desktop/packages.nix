# packages i want on every desktop
{ inputs, ... }:
{
  flake.modules.nixos.desktop = { pkgs, ... }: {
    imports = with inputs.self.modules.nixos; [
      firefox
      ghostty
      zoxide
      zed
      disk-utils
      thunderbird
      cryptomatord
      nix-discord-rpc
      opentabletdriver
    ];

    environment.systemPackages = with pkgs; [
      chezmoi
      mise
      zellij
      nushell
      jq
      ripgrep
      unzip
      wl-clipboard
      nix-output-monitor
      nh

      git
      delta
      lazygit
      gh
      tea

      neovim
      tree-sitter
      vscode

      nixd
      nil
      nixfmt
      lua-language-server
      typst
      tinymist
      websocat # for typst-preview.nvim

      pavucontrol

      mpv
      moonlight-qt
      qalculate-qt
      gthumb
      kdePackages.okular
      zathura

      broot
      file-roller
      kdePackages.dolphin
      kdePackages.kio
      kdePackages.kio-admin
      kdePackages.kio-extras
      kdePackages.kio-fuse
      kdePackages.baloo
      kdePackages.baloo-widgets
      kdePackages.dolphin-plugins
      kdePackages.kdegraphics-thumbnailers
    ];
  };
}
