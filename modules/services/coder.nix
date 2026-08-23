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
        { ... }:
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
              size = 131072;
            }
          ];

          systemd.services.coder.after = [ "postgresql.service" ];

          # Coder's Terraform provisioner is part of the service closure.
          nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "terraform" ];

          networking.firewall.allowedTCPPorts = [ 3000 ];

          services.coder = {
            enable = true;
            listenAddress = "${addr.guestAddr}:3000";
            accessUrl = "https://coder.7sref";
            wildcardAccessUrl = "*.coder.7sref";
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
        # Route generated Coder app subdomains to the Coder server.
        modules.gateway.services.coder-apps = {
          name = "Coder workspace apps";
          domainName = "*.coder";
          addr = "${addr.guestAddr}:3000";
          category = "Development";
          hidden = true;
        };
      };
    }
  ];
}
