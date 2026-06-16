{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos."hosts/nixos/staging" = {
    imports = [
      ./_disko.nix
      ./_configuration.nix
      ./_remote-desktop.nix

      inputs.disko.nixosModules.default
    ]
    ++ (with config.flake.modules.nixos; [
      uefi
      impermanence-zfs
      persistence
      sops

      callum

      ssh
      tailscale

      desktop
      ghostty
    ]);
  };
}
