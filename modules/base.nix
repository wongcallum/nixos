{ inputs, ... }:
{
  flake.modules.nixos.base =
    { pkgs, ... }:
    {
      imports = [ inputs.self.modules.generic.utils ];

      time.timeZone = "Australia/Sydney";
      i18n.defaultLocale = "en_US.UTF-8";

      security.pki.certificateFiles = [ ./7sref_ca.pem ];

      environment.systemPackages = [
        inputs.ghostty.packages.${pkgs.system}.default.terminfo
      ];

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
          extra-substituters = [
            "https://ghostty.cachix.org"
          ];
          extra-trusted-public-keys = [
            "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
          ];
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

      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
        extraConfig = ''
          Defaults lecture = always
          Defaults lecture_file = ${pkgs.writeText "sudo-lecture" ''
            A friendly reminder:

            This system is managed by NixOS. Direct modifications
            to the system will be lost. The root filesystem is
            ephemeral and wiped on every boot.

            Make changes to /persist/nixos-conf instead.
          ''}
        '';
      };

      # make a symlink of flake within the generation (e.g. /run/current-system/src)
      # thank you @iynaix
      system.systemBuilderCommands = "ln -s ${inputs.self.sourceInfo.outPath} $out/src";
    };
}
