{
  config,
  inputs,
  ...
}:
{
  flake.nixpkgs.staging = "unstable";

  flake.modules.nixos."hosts/nixos/staging" = {
    imports = [
      ./_disko.nix
      ./_configuration.nix
      ./_remote-desktop.nix
      ../shama/_packages.nix

      inputs.disko.nixosModules.default
    ]
    ++ (with config.flake.modules.nixos; [
      uefi
      impermanence-zfs
      persistence
      zram

      callum

      ssh
      tailscale

      audio
      desktop
      niri
      fonts
      firefox
      ghostty
      nix-ld
      direnv
      zoxide
    ]);
  };
}
