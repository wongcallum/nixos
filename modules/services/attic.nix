{ lib, ... }:
let
  # What guests dial for the attic guest port.
  guestHost = cfg: "${cfg.guestAddress}:${toString cfg.guestPort}";
in
{
  flake.modules.nixos = {
    global =
      { config, ... }:
      {
        options.modules.attic = {
          cacheName = lib.mkOption {
            type = lib.types.str;
            default = "homelab";
            description = "Name of the attic cache CI pushes to and hosts pull from";
          };

          domainName = lib.mkOption {
            type = lib.types.str;
            default = "attic";
            description = "Internal hostname the cache is served under";
          };

          endpoint = lib.mkOption {
            type = lib.types.str;
            default = "https://${config.modules.attic.domainName}.${config.modules.gateway.tld}/";
            description = "Base URL this host reaches the attic server at";
          };

          guestPort = lib.mkOption {
            type = lib.types.port;
            default = 8081;
            description = ''
              Plain-HTTP port the attic host serves the cache on for VM guests,
              which can reach neither the gateway nor its DNS
            '';
          };

          guestAddress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "10.0.1.1";
            description = ''
              The attic host's address on the VM network, where guests reach
              guestPort. Null turns the guest port off.
            '';
          };

          priority = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            example = 10;
            description = ''
              Substituter priority that overrides the cache's own. Nix asks lower
              values first. Null keeps the priority attic advertises.
            '';
          };

          staticSubstituter = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether nix.conf lists the cache as a substituter. Set it to false
              when something else adds it at runtime.
            '';
          };

          substituter = lib.mkOption {
            type = lib.types.str;
            default =
              let
                cfg = config.modules.attic;
              in
              "${cfg.endpoint}${cfg.cacheName}${
                lib.optionalString (cfg.priority != null) "?priority=${toString cfg.priority}"
              }";
            readOnly = true;
            description = "The cache's substituter URL exactly as it appears in nix.conf";
          };

          publicKey = lib.mkOption {
            type = lib.types.str;
            default = "homelab:GtiQKpn+dfjJjjpPZQtQf2MZMzhFn2DQG9lkxxfarLc=";
            description = ''
              Signing key attic generated when the cache was created, in `<cache>:<base64>` form
            '';
          };
        };
      };

    base =
      { config, ... }:
      let
        cfg = config.modules.attic;
      in
      {
        nix.settings = {
          extra-substituters = lib.optional cfg.staticSubstituter cfg.substituter;
          extra-trusted-public-keys = lib.optional (cfg.publicKey != "") cfg.publicKey;
        };
      };

    attic =
      { config, lib, ... }:
      let
        cfg = config.modules.attic;

        pool = "scratch";
        dataset = "${pool}/attic";
        root = "/${dataset}";
        storage = "${root}/storage";

        # Keep the fsync-heavy database off scratch's spinning disk.
        dataDir = config.utils.dataDir "attic";
        database = "${dataDir}/server.db";

        listenPort = 8080;
      in
      {
        options.modules.attic = {
          retention = lib.mkOption {
            type = lib.types.str;
            default = "60 days";
            description = "How long an unreferenced object survives.";
          };
        };

        config = {
          systemd = {
            tmpfiles.rules = [ "d ${dataDir} 0750 atticd atticd -" ];

            services.atticd = {
              # scratch/attic is created by hand.
              after = [
                "zfs-import-${pool}.service"
                "zfs-mount.service"
              ];

              serviceConfig = {
                DynamicUser = lib.mkForce false;
                # SQLite writes its journal beside the database.
                ReadWritePaths = [
                  root
                  dataDir
                ];
              };
            };
          };

          users.users.atticd = {
            isSystemUser = true;
            group = "atticd";
          };
          users.groups.atticd = { };

          sops.secrets."attic/server-env" = {
            restartUnits = [ "atticd.service" ];
          };

          services.atticd = {
            enable = true;
            user = "atticd";
            group = "atticd";
            environmentFile = config.sops.secrets."attic/server-env".path;

            settings = {
              listen = "127.0.0.1:${toString listenPort}";
              allowed-hosts = [
                "${cfg.domainName}.${config.modules.gateway.tld}"
              ]
              ++ lib.optional (cfg.guestAddress != null) (guestHost cfg);
              # Unset, so attic derives it from X-Forwarded-*. Guests can't resolve the gateway.

              database.url = "sqlite://${database}?mode=rwc";

              storage = {
                type = "local";
                path = storage;
              };

              # The default 64 KiB average is too small for a spinning disk.
              chunking = {
                nar-size-threshold = 65536; # 64 KiB
                min-size = 65536; # 64 KiB
                avg-size = 262144; # 256 KiB
                max-size = 1048576; # 1 MiB
              };

              garbage-collection = {
                interval = "12 hours";
                default-retention-period = cfg.retention;
              };
            };
          };
        };
      };

    gateway =
      { config, lib, ... }:
      {
        modules.gateway.services.attic = lib.mkIf config.services.atticd.enable {
          name = "Attic";
          domainName = config.modules.attic.domainName;
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/nixos.svg";
          addr = config.services.atticd.settings.listen;
          category = "Development";
        };

        services.caddy.virtualHosts."http://:${toString config.modules.attic.guestPort}" =
          lib.mkIf (config.services.atticd.enable && config.modules.attic.guestAddress != null)
            {
              extraConfig = ''
                # attic builds the endpoints it returns from X-Forwarded-Host.
                reverse_proxy ${config.services.atticd.settings.listen} {
                  header_up Host ${guestHost config.modules.attic}
                  header_up X-Forwarded-Host ${guestHost config.modules.attic}
                  header_up X-Forwarded-Proto http
                }
              '';
            };
      };
  };
}
