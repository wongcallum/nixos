{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake) keys;
  inherit (config.flake.modules) nixos;

  # Every ISO runs tailscaled, but only enrols itself when the ISO carries an
  # OAuth client secret, which scripts/iso-add-tailscale-key.sh adds to a built
  # image. The secret never enters the Nix store, so the image built here (and
  # by CI) is generic.
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
        # the secret is an OAuth client's, which mints a key with these
        authKeyParameters = {
          ephemeral = true;
          preauthorized = true;
        };
        extraDaemonFlags = [ "--state=mem:" ];
        extraUpFlags = [
          "--hostname=nixos-installer"
          # required for OAuth secrets; the tailnet policy confines this tag
          # to attic's guest port on liz
          "--advertise-tags=tag:installer"
          # resolved already sends every lookup over strict DoT; tailnet DNS
          # would only add the 7sref names, which the policy blocks
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
        # attic's plain-HTTP guest port, the one thing tag:installer may reach
        endpoint = "http://${hostAddrs.liz}:${toString attic.guestPort}/";
        # Listing an unreachable cache costs a connect timeout per nix
        # command, so it's added only once the tailnet can reach it
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
        # Probe attic only while tailscale is up, so an ISO that never joins
        # sends nothing towards liz's address
        script = ''
          until [[ "$(tailscale status --json --peers=false | jq -r .BackendState)" == Running ]] \
            && curl -fsS -m 5 -o /dev/null ${attic.endpoint}${attic.cacheName}/nix-cache-info; do
            sleep 5
          done
          mkdir -p ${dirOf atticConf}
          echo "extra-substituters = ${attic.substituter}" >${atticConf}
          # nix-daemon reads nix.conf only at startup. Its unit has
          # KillMode=process, so builds and installs already running carry on.
          systemctl try-restart nix-daemon.service
          echo "added ${attic.substituter}"
        '';
      };
    };

  # Strict DNS-over-TLS to Cloudflare, ignoring the network's resolvers, so
  # lookups can't be read or rewritten on the way. On a network that blocks
  # port 853, lift it at runtime:
  #   mkdir -p /run/systemd/resolved.conf.d
  #   printf '[Resolve]\nDNSOverTLS=no\n' >/run/systemd/resolved.conf.d/plain.conf
  #   systemctl restart systemd-resolved
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
    # Keep NetworkManager from handing DHCP-supplied resolvers to resolved,
    # which would query them too: over TLS, but with no name to check the
    # certificate against. dns = "none" alone still pushes them over D-Bus.
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
            # the live system's root isn't ZFS; this is the default from 26.11
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
