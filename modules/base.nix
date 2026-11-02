{ inputs, lib, ... }:
{
  flake.modules.nixos.base =
    {
      options,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.self.modules.generic.utils ];
      nixpkgs.config.allowUnfree = true;

      time.timeZone = "Australia/Sydney";
      i18n.defaultLocale = "en_US.UTF-8";

      security.pki.certificateFiles = [ ./7sref_ca.pem ];

      environment.variables = {
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"; # python httpx/aiohttp/ssl
        REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt"; # python requests
        NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt"; # unpatched node (electron)
      };

      environment.systemPackages = [
        pkgs.ghostty.terminfo
      ];

      # Unlike nix.gc, `nh clean all` also prunes users' ~/.local/state/nix profiles.
      programs.nh.clean = {
        enable = true;
        dates = "weekly";
        extraArgs = "--keep-since 30d --keep 5";
      };

      nix = {
        # https://jackson.dev/post/nix-reasonable-defaults/
        extraOptions = ''
          connect-timeout = 5
          log-lines = 50
          fallback = true
        '';

        optimise = {
          automatic = true;
          dates = [ "04:00" ];
        };

        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          download-buffer-size = 524288000;

          min-free = lib.mkDefault 128000000;
          max-free = lib.mkDefault 1000000000;

          # Third-party binary caches are deliberately not set as substituters here.
          # Hosts get those paths from attic once CI has pushed their closure.
          # See extra-substituters in hosts/nixos/vm-ci/default.nix
        };
      };

      documentation.man.cache.enable = false;

      services.journald =
        if options.services.journald ? settings then
          {
            settings.Journal = {
              SystemMaxUse = "100M";
              MaxFileSec = "3day";
            };
          }
        else
          {
            extraConfig = ''
              SystemMaxUse=100M
              MaxFileSec=3day
            '';
          };

      security.sudo = {
        extraConfig = ''
          Defaults lecture = never
        '';
      };
    };
}
