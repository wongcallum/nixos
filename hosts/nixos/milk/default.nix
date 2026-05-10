{ config, ... }:
{
  flake.modules.nixos."hosts/nixos/milk" = {
    imports = with config.flake.modules.nixos; [
      ./_configuration.nix

      callum

      ssh
      tailscale
    ];
  };
}
