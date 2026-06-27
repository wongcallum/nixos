{
  flake.modules.nixos.plasma = { pkgs, ... }: {
    services.desktopManager.plasma6.enable = true;
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      plasma-browser-integration
      konsole
      elisa
      ark
      gwenview
      okular # redefined in _packages.nix
      kate
      ktexteditor
      khelpcenter
      ffmpegthumbs

      plasma-keyboard
      qtvirtualkeyboard
      krdp
      # kwin-x11 # might be useful for testing

      # dolphin baloo-widgets dolphin-plugins
    ];
  };
}
