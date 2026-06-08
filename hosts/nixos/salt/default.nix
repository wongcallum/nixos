{ config, inputs, ... }:
{
  flake.modules.nixos."hosts/nixos/salt" = {
    imports = [
      ./_disko.nix
      ./_configuration.nix

      inputs.disko.nixosModules.default
    ]
    ++ (with config.flake.modules.nixos; [
      uefi
      zram

      callum

      ssh
      tailscale
      sops

      quadlet-lobehub
    ]);
  };
}
