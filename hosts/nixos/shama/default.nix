{ config, inputs, ... }:
{
  flake.nixpkgs.shama = "unstable";

  flake.modules.nixos."hosts/nixos/shama" = {
    imports = [
      ./_configuration.nix
      ./_disko.nix
      ./_packages.nix

      inputs.disko.nixosModules.default
    ]
    ++ (with config.flake.modules.nixos; [
      limine
      zram

      callum
      tailscale
      zed
      nix-monitored

      impermanence-btrfs

      audio
      desktop
      niri
      plasma
      keyd
      libvirt
      docker
      fonts
      bluetooth
      firefox
      ungoogled-chromium
      ghostty
      laptop
      nix-ld
      syncthing-desktop
      direnv
      zoxide
    ]);

    environment.variables.EDITOR = "nvim";

    nixpkgs.overlays = [
      (final: prev: {
        nnn = prev.nnn.overrideAttrs {
          version = "5.3-unstable-2026-05-29";
          src = final.fetchFromGitHub {
            owner = "jarun";
            repo = "nnn";
            rev = "2f1d36273ac256723781be82088d6f95edbbe2e5";
            sha256 = "sha256-u77QZOlzLZ4CDjZmuGnyEF9avOoMbLxnRO7M2JHTb1g=";
          };
        };
      })
    ];

    networking.networkmanager.enable = true;
    services.resolved.enable = true;
    documentation.man.cache.enable = false;

    modules.syncthing-desktop.user = "callum";

    users.users.callum.extraGroups = [
      "networkmanager"
      "adbusers"
    ];

    system.stateVersion = "26.05";
  };
}
