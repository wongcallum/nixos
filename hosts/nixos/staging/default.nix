{ config, ... }:
{
  flake.modules.nixos."hosts/nixos/staging" = {
    imports =
      (with config.flake.nixosModules; [
        staging-disko
        staging-configuration
      ])
      ++ (with config.flake.modules.nixos; [
        uefi
        impermanence-zfs
        persistence
        sops

        callum

        ssh
        tailscale
      ]);
  };
}
