{ pkgs, ... }:
let
  lobehub-desktop = pkgs.callPackage ../../../packages/lobehub-desktop { };
in
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
    nushell
    jq
    ripgrep
    wl-clipboard
    wget
    unzip

    ## informational/helper
    ncdu
    btop
    nix-output-monitor
    nix-search-cli
    nix-your-shell
    nh

    # editors
    neovim
    tree-sitter
    vscode
    # zed-editor comes from the `zed` module (my fork + blur patch)

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
    file-roller

    # system
    kdePackages.qttools
    adwaita-icon-theme
    pavucontrol
    blueman
    efibootmgr

    # bloat
    equibop
    feishin
    jetbrains-toolbox
    lobehub-desktop
  ];
}
