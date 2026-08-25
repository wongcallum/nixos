{
  config,
  inputs,
  lib,
  deployLib,
  ...
}:
let
  mkHosts =
    prefix: modules: builder:
    lib.mapAttrs' (
      name: module:
      let
        hostname = lib.removePrefix prefix name;
      in
      {
        name = hostname;
        value = builder hostname module;
      }
    ) (lib.filterAttrs (name: _: lib.hasPrefix prefix name) modules);
in
{
  options.flake.nixpkgs = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "nixpkgs input name per host";
  };

  config =
    let
      # Real machines only. Installer images are also nixosConfigurations, but
      # they are not deploy targets, so they must not reach `flake.deploy.nodes`.
      machines = mkHosts "hosts/nixos/" config.flake.modules.nixos (
        hostname: module:
        let
          baseName = config.flake.nixpkgs.${hostname} or "nixpkgs";
          system = "x86_64-linux";
        in
        inputs.${baseName}.lib.nixosSystem {
          inherit system;
          specialArgs = lib.recursiveUpdate inputs { inherit inputs; };
          modules = [
            { networking.hostName = hostname; }
            config.flake.modules.nixos.base
            config.flake.modules.nixos.global
            module
          ];
        }
      );
    in
    {
      flake.nixosConfigurations = lib.mkMerge [
        machines

        (config.flake.modules.iso or { })
      ];

      flake.deploy.nodes = lib.mapAttrs (hostname: hostConfiguration: {
        inherit hostname;
        profiles.system = {
          user = "root";
          sshUser = "callum";
          path = deployLib.activate.nixos hostConfiguration;
        };
      }) machines;
    };
}
