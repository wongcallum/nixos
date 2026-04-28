{ config, ... }:
{
  flake.modules.nixos."hosts/nixos/liz" = {
    imports =
      (with config.flake.nixosModules; [
        liz-disko
        liz-configuration
        liz-networking
      ])
      ++ (with config.flake.modules.nixos; [
        uefi
        zram
        impermanence-zfs
        persistence
        sops

        callum
        colin

        ssh
        tailscale
        gateway
        monitoring
        samba
        syncthing
        qbittorrent

        quadlet-productivity
        quadlet-media
        quadlet-automation
        quadlet-development
      ]);
  };
}
