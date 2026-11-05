{
  config,
  inputs,
  lib,
  deployLibFor,
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

  options.flake.systems = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "System per host; defaults to x86_64-linux";
  };

  config =
    let
      # Excludes the installer images, which aren't deploy targets.
      machines = mkHosts "hosts/nixos/" config.flake.modules.nixos (
        hostname: module:
        let
          baseName = config.flake.nixpkgs.${hostname} or "nixpkgs";
          system = config.flake.systems.${hostname} or "x86_64-linux";
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
      flake.nixosConfigurations = machines;

      flake.deploy.nodes = lib.mapAttrs (hostname: hostConfiguration: {
        inherit hostname;
        # Other architectures can't build here.
        remoteBuild = hostConfiguration.pkgs.stdenv.hostPlatform.system != "x86_64-linux";
        profiles.system = {
          user = "root";
          sshUser = "callum";
          interactiveSudo = !(hostConfiguration.config.modules.users.callum.lockPassword or false);
          path = (deployLibFor hostConfiguration.pkgs.stdenv.hostPlatform.system).activate.nixos hostConfiguration;
        };
      }) machines;
    };
}
