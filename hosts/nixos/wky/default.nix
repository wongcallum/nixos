{ config, ... }:
{
  flake.nixpkgs.wky = "unstable";

  flake.modules.nixos."hosts/nixos/wky" = {
    imports = [
      ./_configuration.nix
      ./_packages.nix
    ]
    ++ (with config.flake.modules.nixos; [
      zram
      callum
      tailscale

      audio
      desktop
      libvirt
      docker
      fonts
      bluetooth
      firefox
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
    services.xserver.xkb.options = "caps:escape";
    documentation.man.cache.enable = false;

    modules.syncthing-desktop.user = "callum";

    users.users.callum.extraGroups = [
      "networkmanager"
      "adbusers"
    ];

    system.stateVersion = "25.11";
  };
}
