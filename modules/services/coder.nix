{
  config,
  lib,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;

  n = 2;
  hostname = "vm-coder";
  addr = microvmLib.addressing n;
in
{
  flake.modules = lib.mkMerge [
    {
      nixos.coder =
        { pkgs, ... }:
        {
          imports = [
            nixos.docker
            nixos.persistence
            nixos.ssh
            (microvmLib.mkGuestModule {
              inherit n hostname;
            })
          ];

          environment.persistence."/persist".directories = [
            "/var/lib/coder"
            "/var/lib/postgresql"
          ];

          # Docker's overlayfs snapshotter cannot use the virtiofs-backed
          # persistence directory as its upper/work filesystem. Keep the
          # Docker state persistent, but put it on a guest-local ext4 volume.
          microvm.volumes = [
            {
              image = "/persist/microvms/${hostname}-docker.img";
              mountPoint = "/var/lib/docker";
              size = 32768;
            }
          ];

          # Migrate Docker state from the old virtiofs-backed persistence path
          # the first time the local Docker volume is booted.
          systemd.services = {
            docker-state-migration = {
              description = "Migrate Docker state to the local Docker volume";
              wantedBy = [ "docker.service" ];
              before = [
                "containerd.service"
                "docker.service"
              ];
              after = [
                "persist.mount"
                "var-lib-docker.mount"
              ];
              requires = [
                "persist.mount"
                "var-lib-docker.mount"
              ];
              unitConfig.ConditionPathExists = "/persist/var/lib/docker";
              path = [
                pkgs.findutils
                pkgs.rsync
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                if [ -e /var/lib/docker/engine-id ] || [ -e /var/lib/docker/volumes/metadata.db ]; then
                  exit 0
                fi

                rsync --archive --hard-links --acls --xattrs --numeric-ids \
                  /persist/var/lib/docker/ /var/lib/docker/
              '';
            };

            docker = {
              after = [ "docker-state-migration.service" ];
              requires = [ "docker-state-migration.service" ];
            };

            coder.after = [ "postgresql.service" ];
          };

          # Coder's Terraform provisioner is part of the service closure.
          nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "terraform" ];

          networking.firewall.allowedTCPPorts = [ 3000 ];

          services.coder = {
            enable = true;
            listenAddress = "${addr.guestAddr}:3000";
            accessUrl = "https://coder.7sref";
            database.createLocally = true;
            environment.extra.CODER_TELEMETRY_ENABLE = "false";
          };

          users.users.coder.extraGroups = [ "docker" ];
        };
    }
    {
      nixos.gateway = {
        modules.gateway.services.coder = {
          name = "Coder";
          domainName = "coder";
          addr = "${addr.guestAddr}:3000";
          category = "Development";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/coder-light.svg"; # mislabelled, actually for dark
        };
      };
    }
  ];
}
