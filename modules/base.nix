{
  flake.modules.nixos.base = {
    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_US.UTF-8";

    nix = {
      optimise = {
        automatic = true;
        dates = [ "04:00" ];
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };
  };
}
