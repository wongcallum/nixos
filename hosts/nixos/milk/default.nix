{ inputs, config, ... }:
{
  flake.modules.nixos."hosts/nixos/milk" = {
    imports = with config.flake.modules.nixos; [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/digital-ocean-image.nix"

      ./_configuration.nix

      callum

      ssh
      tailscale
    ];
  };
}
