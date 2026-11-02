{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake) keys;
  inherit (config.flake.modules) nixos;

  # added to a built image by scripts/iso-add-tailscale-key.sh, never the store
  tsSecretFile = "/iso/tailscale/oauth-secret";

  # nix.conf includes this, and attic-substituter writes it once attic answers
  atticConf = "/run/nix/attic.conf";

  tailscaleInstaller =
    { config, pkgs, ... }:
    let
      inherit (config.modules) hostAddrs;
      attic = config.modules.attic;
    in
    {
      services.tailscale = {
        enable = true;
        authKeyFile = tsSecretFile;
        authKeyParameters = {
          ephemeral = true;
          preauthorized = true;
        };
        extraDaemonFlags = [ "--state=mem:" ];
        extraUpFlags = [
          "--hostname=nixos-installer"
          # required for OAuth secrets
          "--advertise-tags=tag:installer"
          # resolved already uses strict DoT
          "--accept-dns=false"
        ];
      };

      systemd.services.tailscaled-autoconnect = {
        unitConfig = {
          ConditionPathExists = tsSecretFile;
          # keep trying until a network comes up, e.g. wifi set up by hand
          StartLimitIntervalSec = 0;
        };
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      modules.attic = {
        endpoint = "http://${hostAddrs.liz}:${toString attic.guestPort}/";
        # an unreachable cache costs a timeout per nix command; added once reachable
        staticSubstituter = false;
      };

      nix.extraOptions = ''
        !include ${atticConf}
      '';

      systemd.services.attic-substituter = {
        description = "Add attic as a substituter once it is reachable over Tailscale";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          config.services.tailscale.package
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = {
          # simple rather than oneshot, so waiting doesn't hold up boot
          Type = "simple";
          RemainAfterExit = true;
        };
        # an ISO that never joins sends nothing towards liz
        script = ''
          until [[ "$(tailscale status --json --peers=false | jq -r .BackendState)" == Running ]] \
            && curl -fsS -m 5 -o /dev/null ${attic.endpoint}${attic.cacheName}/nix-cache-info; do
            sleep 5
          done
          mkdir -p ${dirOf atticConf}
          echo "extra-substituters = ${attic.substituter}" >${atticConf}
          # KillMode=process: running builds survive
          systemctl try-restart nix-daemon.service
          echo "added ${attic.substituter}"
        '';
      };
    };

  # if port 853 is blocked, set DNSOverTLS=no in /run/systemd/resolved.conf.d
  dnsOverTls = {
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNS = [
          "1.1.1.1#cloudflare-dns.com"
          "1.0.0.1#cloudflare-dns.com"
          "2606:4700:4700::1111#cloudflare-dns.com"
          "2606:4700:4700::1001#cloudflare-dns.com"
        ];
        DNSOverTLS = true;
      };
    };
    # dns = "none" alone still pushes DHCP resolvers to resolved over D-Bus
    networking.networkmanager = {
      dns = lib.mkForce "none";
      settings.main.systemd-resolved = false;
    };
  };

  mkIso =
    nixpkgs: isoPath:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/${isoPath}.nix"

        nixos.base
        nixos.global
        tailscaleInstaller
        dnsOverTls

        (
          { pkgs, ... }:
          {
            boot.loader.grub.memtest86.enable = true;
            boot.zfs.forceImportRoot = false;
            isoImage.makeBiosBootable = true;

            environment.systemPackages = with pkgs; [
              btop
              ripgrep
              neovim
            ];

            environment.variables = {
              EDITOR = "nvim";
              NIXPKGS_ALLOW_UNFREE = "1";
            };

            networking.networkmanager.enable = true;

            programs.nano.enable = false;

            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = true;
              };
            };

            users.users.root.openssh.authorizedKeys.keys = keys.callum;

            services.avahi = {
              enable = true;
              nssmdns4 = true;
              publish = {
                enable = true;
                addresses = true;
                workstation = true;
              };
            };

            systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

            nix = {
              package = pkgs.nixVersions.latest;
              settings = {
                substituters = [
                  "https://nix-community.cachix.org"
                ];
                trusted-public-keys = [
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
              };
            };
          }
        )
      ];
    };
in
{
  flake.nixosConfigurations = {
    minimal-iso = mkIso inputs.nixpkgs "installation-cd-minimal";
    kde-iso = mkIso inputs.nixpkgs "installation-cd-graphical-calamares-plasma6";
  };
}
