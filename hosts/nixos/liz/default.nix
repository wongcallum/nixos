{
  config,
  inputs,
  ...
}:
let
  hostname = "liz";
  system = "x86_64-linux";
in
{
  flake.deploy.nodes.${hostname} = {
    inherit hostname;
    profiles.system = {
      user = "root";
      sshUser = "callum";
      path = inputs.deploy-rs.lib.${system}.activate.nixos config.flake.nixosConfigurations.${hostname};
    };
  };

  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      { networking.hostName = hostname; }
      config.flake.modules.nixos.${hostname}
      inputs.disko.nixosModules.default
      inputs.quadlet-nix.nixosModules.quadlet
    ];
  };

  flake.modules.nixos.${hostname} = {
    imports =
      (with config.flake.nixosModules; [
        liz-disko
        liz-configuration
        liz-networking
      ])
      ++ (with config.flake.modules.nixos; [
        base
        uefi
        zram

        impermanence-zfs
        persistence

        callum
        colin

        ssh
        tailscale
      ]);
  };
}
