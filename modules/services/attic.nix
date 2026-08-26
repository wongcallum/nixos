{ lib, ... }:
{
  flake.modules.nixos = {
    global = _: {
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
      {
        nix.settings = {
          extra-substituters = [
            "https://${config.modules.attic.domainName}.${config.modules.gateway.tld}/${config.modules.attic.cacheName}"
          ];
          extra-trusted-public-keys = lib.optional (
            config.modules.attic.publicKey != ""
          ) config.modules.attic.publicKey;
        };
      };

    # requires flake.modules.nixos.sops
    attic =
      { config, lib, ... }:
      let
        cfg = config.modules.attic;

        pool = "scratch";
        dataset = "${pool}/attic";
        root = "/${dataset}";
        storage = "${root}/storage";

        # server.db does small fsync-heavy writes per chunk pushed, which is
        # IOPS-bound; scratch is a single spinning disk, so keep the database
        # off it and on the SSD-backed persist dataset instead. Bulk chunk
        # storage stays on scratch since it's comparatively sequential and
        # needs the capacity more than the speed.
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
              # the scratch/attic dataset is provisioned manually on each host,
              # not by this module, so just wait for the pool to be there
              after = [
                "zfs-import-${pool}.service"
                "zfs-mount.service"
              ];

              serviceConfig = {
                DynamicUser = lib.mkForce false;
                # and sqlite needs to write its journal into the containing directory too
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
            owner = "root";
            group = "root";
            mode = "0400";
            restartUnits = [ "atticd.service" ];
          };

          services.atticd = {
            enable = true;
            user = "atticd";
            group = "atticd";
            environmentFile = config.sops.secrets."attic/server-env".path;

            settings = {
              listen = "127.0.0.1:${toString listenPort}";
              allowed-hosts = [ "${cfg.domainName}.${config.modules.gateway.tld}" ];
              api-endpoint = "https://${cfg.domainName}.${config.modules.gateway.tld}/";

              database.url = "sqlite://${database}?mode=rwc";

              storage = {
                type = "local";
                path = storage;
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
      };
  };
}
