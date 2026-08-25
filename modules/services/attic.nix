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
          default = "";
          example = "homelab:tQ6cKz1ktFAWpKC0DAKFVYLXmPFOcVMLcnhPBGYqLTU=";
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
        database = "${root}/server.db";

        listenPort = 8080;
      in
      {
        options.modules.attic = {
          quota = lib.mkOption {
            type = lib.types.str;
            default = "300G";
          };

          retention = lib.mkOption {
            type = lib.types.str;
            default = "60 days";
            description = "How long an unreferenced object survives.";
          };
        };

        config = {
          # The scratch pool is imported via boot.zfs.extraPools rather than
          # declared in disko, so the dataset is provisioned here. Properties are
          # re-applied on every start, which keeps changes to them declarative.
          systemd.services.attic-storage = {
            description = "Provision the ZFS dataset backing the attic binary cache";
            requiredBy = [ "atticd.service" ];
            before = [ "atticd.service" ];
            after = [
              "zfs-import-${pool}.service"
              # the dataset has to be mounted before anything is written into it
              "zfs-mount.service"
            ];
            path = [ config.boot.zfs.package ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };

            script = ''
              set -eu

              if ! zfs list -H -o name ${dataset} > /dev/null 2>&1; then
                zfs create -o mountpoint=${root} ${dataset}
              fi

              # attic already compresses chunks
              #
              # sqlite metadata is also in the dataset, and a 1M record might be a bottleneck
              zfs set \
                quota=${cfg.quota} \
                atime=off \
                compression=off \
                recordsize=1M \
                ${dataset}

              install -d -o atticd -g atticd -m 0750 ${root} ${storage}
            '';
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

          systemd.services.atticd.serviceConfig = {
            DynamicUser = lib.mkForce false;
            # and sqlite needs to write its journal into the containing directory too
            ReadWritePaths = [ root ];
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
