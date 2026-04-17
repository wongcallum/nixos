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
        trilium
        qbittorrent

        quadlet-ai
        quadlet-home-assistant
        quadlet-evcc
        quadlet-media
        quadlet-code
      ]);
  };
}
