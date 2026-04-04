{
  config,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
in
{
  flake.deploy.nodes.salt = {
    hostname = "salt";
    profiles.system = {
      user = "root";
      sshUser = "callum";
      path = inputs.deploy-rs.lib.${system}.activate.nixos config.flake.nixosConfigurations.salt;
    };
  };

  flake.nixosConfigurations.salt = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      config.flake.modules.nixos.salt
      inputs.disko.nixosModules.default
    ];
  };

  flake.modules.nixos.salt = {
    imports =
      (with config.flake.nixosModules; [
        salt-disko
        salt-configuration
      ])
      ++ (with config.flake.modules.nixos; [
        callum

        base
        ssh
        tailscale
      ]);
  };
}
