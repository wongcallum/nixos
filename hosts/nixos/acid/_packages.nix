{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    gh
    jq
    ripgrep
    wl-clipboard
    unzip
    btop
    neovim
    nil
    nixfmt
    nemo
    pavucontrol
    blueman
    adwaita-icon-theme
    chezmoi
    lazygit
    nnn
  ];
}
