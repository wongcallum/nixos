{ inputs, ... }:
{
  flake.modules.nixos.desktop = { pkgs, ... }: {
    imports = with inputs.self.modules.nixos; [
      firefox
      ghostty
      zed
      disk-utils
      thunderbird
      cryptomatord
      nix-discord-rpc
      opentabletdriver
    ];

    environment.systemPackages = with pkgs; [
      wl-clipboard

      vscode

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
