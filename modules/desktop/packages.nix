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
      nix-output-monitor
      opentabletdriver
    ];

    environment.systemPackages = with pkgs; [
      chezmoi
      mise
      devenv
      zellij
      nushell
      jq
      ripgrep
      unzip
      wl-clipboard
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

      equibop
      feishin
      faugus-launcher
    ];
  };
}
