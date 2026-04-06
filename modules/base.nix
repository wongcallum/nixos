{
  flake.modules.nixos.base = {
    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_US.UTF-8";

    nix = {
      # https://jackson.dev/post/nix-reasonable-defaults/
      extraOptions = ''
        connect-timeout = 5
        log-lines = 50
        min-free = 128000000
        max-free = 1000000000
        fallback = true
      '';

      optimise = {
        automatic = true;
        dates = [ "04:00" ];
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };

      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        download-buffer-size = 524288000;
      };
    };

    documentation = {
      enable = false;
      doc.enable = false;
      info.enable = false;
    };

    services.journald.extraConfig = ''
      SystemMaxUse=100M
      MaxFileSec=3day
    '';

    security.sudo-rs = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
}
