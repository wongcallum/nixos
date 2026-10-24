{ config, microvmLib, ... }:
let
  inherit (config.flake.modules) nixos;

  hostname = "vm-coder";
  addr = microvmLib.addressing hostname;
in
{
  flake.nixpkgs.vm-coder = "unstable";

  flake.modules.nixos."hosts/nixos/vm-coder" =
    { config, ... }:
    {
      imports = [
        nixos.coder
        nixos.persistence
        nixos.ssh
        (microvmLib.mkGuestModule { inherit hostname; })
      ];

      microvm.mem = 8192;

      environment.persistence.${config.modules.persistence.persistDir}.directories = [
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

      networking.firewall.allowedTCPPorts = [ 3000 ];

      services.coder.listenAddress = "${addr.guestAddr}:3000";

      system.stateVersion = "25.11";
    };
}
