{
  config,
  inputs,
  lib,
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

  config = {
    flake.nixosConfigurations = lib.mkMerge [
      (mkHosts "hosts/nixos/" config.flake.modules.nixos (
        hostname: module:
        let
          baseName = config.flake.nixpkgs.${hostname} or "nixpkgs";
          isUnstable = baseName == "unstable";
          system = "x86_64-linux";
        in
        (if isUnstable then inputs.nixpkgs-patcher.lib.nixosSystem else inputs.${baseName}.lib.nixosSystem)
          (
            {
              inherit system;
              specialArgs = inputs;
              modules = [
                { networking.hostName = hostname; }
                config.flake.modules.nixos.base
                config.flake.modules.nixos.global
                module
              ];
            }
            // lib.optionalAttrs isUnstable {
              nixpkgsPatcher = {
                nixpkgs = inputs.unstable;
                patches = _pkgs: [ ../patches/xnviewmp-desktop.patch ];
              };
            }
          )
      ))

      (config.flake.modules.iso or { })
    ];

    flake.deploy.nodes = lib.mapAttrs (hostname: hostConfiguration: {
      inherit hostname;
      profiles.system = {
        user = "root";
        sshUser = "callum";
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos hostConfiguration;
      };
    }) config.flake.nixosConfigurations;
  };
}
