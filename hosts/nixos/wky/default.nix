{ config, inputs, ... }:
{
  flake.nixpkgs.wky = "unstable";

  flake.modules.nixos."hosts/nixos/wky" = {
    imports = [
      ./_configuration.nix
      ./_packages.nix

      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
          backupFileExtension = "backup";

          users.callum = ./_home.nix;
        };
      }
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
      laptop
      nix-ld
      noctalia
      syncthing-desktop
      yazi
    ]);

    networking.networkmanager.enable = true;
    services.resolved.enable = true;
    documentation.man.cache.enable = false;

    modules.syncthing-desktop.user = "callum";

    users.users.callum.extraGroups = [
      "networkmanager"
      "adbusers"
    ];

    system.stateVersion = "25.11";
  };
}
