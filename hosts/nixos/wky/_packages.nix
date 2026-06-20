{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # terminal tools
    zellij
    chezmoi
    mise
    android-tools

    ## fish plugins
    fishPlugins.tide
    fishPlugins.autopair

    ## git
    git
    delta
    lazygit
    gh

    ## general purpose
    jq
    ripgrep
    wl-clipboard
    wget
    unzip

    ## informational/helper
    ncdu
    btop
    nix-output-monitor
    nh

    # editors
    neovim
    tree-sitter
    vscode
    zed-editor

    # lsp/format
    nixd
    nil
    nixfmt
    lua-language-server
    markdown-oxide
    typst
    tinymist
    websocat # for typst-preview.nvim

    # productivity
    xournalpp
    libreoffice-fresh
    qalculate-gtk
    foliate
    kdePackages.okular
    zathura
    xnviewmp
    scrcpy
    mpv

    # file manager
    nemo
    nnn
    doublecmd

    # system
    kdePackages.qttools
    adwaita-icon-theme
    pavucontrol
    blueman

    # bloat
    vesktop
    feishin
  ];
}
