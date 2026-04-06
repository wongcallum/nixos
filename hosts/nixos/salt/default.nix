{
  config,
  inputs,
  ...
}:
let
  hostname = "salt";
  system = "x86_64-linux";
in
{
  flake.deploy.nodes.${hostname} = {
    inherit hostname;
    profiles.system = {
      user = "root";
      sshUser = "callum";
      path = inputs.deploy-rs.lib.${system}.activate.nixos config.flake.nixosConfigurations.salt;
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
        salt-disko
        salt-configuration
      ])
      ++ (with config.flake.modules.nixos; [
        base
        uefi

        callum

        ssh
        tailscale
        mc-server
      ]);
  };
}
