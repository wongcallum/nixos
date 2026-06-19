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
      ../wky/_packages.nix

      inputs.disko.nixosModules.default
    ]
    ++ (with config.flake.modules.nixos; [
      uefi
      impermanence-zfs
      persistence
      sops
      zram

      callum

      ssh
      tailscale

      audio
      desktop
      fonts
      firefox
      ghostty
      hackneyed-cursors
      nix-ld
      direnv
      zoxide
    ]);
  };
}
