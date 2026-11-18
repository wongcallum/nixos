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
      # Every switch method builds this attribute, so the profile it sets carries the
      # revision for scripts/revs.sh. Only the flake's view of the toplevel is wrapped:
      # the system inside is untouched, so a commit that doesn't change a host leaves
      # its closure alone. Hosts that embed another host (liz's guests) must go through
      # `unwrapped`, or they'd change on every commit too.
      withRevision =
        host:
        let
          inherit (host.config.system.build) toplevel;
        in
        host
        // {
          unwrapped = host;
          config = host.config // {
            system = host.config.system // {
              build = host.config.system.build // {
                toplevel = host.pkgs.buildEnv {
                  inherit (toplevel) name;
                  paths = [
                    toplevel
                    (host.pkgs.writeTextDir "config-revision" (inputs.self.rev or inputs.self.dirtyRev or "unknown"))
                  ];
                };
              };
            };
          };
        };

      # Excludes the installer images, which aren't deploy targets.
      machines = mkHosts "hosts/nixos/" config.flake.modules.nixos (
        hostname: module:
        let
          baseName = config.flake.nixpkgs.${hostname} or "nixpkgs";
          system = config.flake.systems.${hostname} or "x86_64-linux";
        in
        withRevision (
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
        )
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
