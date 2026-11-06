{ inputs, lib, ... }:
let
  byName = ../../pkgs/by-name;
  packageFiles = lib.concatMapAttrs (
    shard: _:
    lib.mapAttrs (name: _: byName + "/${shard}/${name}/package.nix") (
      builtins.readDir (byName + "/${shard}")
    )
  ) (builtins.readDir byName);
in
{
  flake.overlays.default =
    final: _prev: lib.mapAttrs (_: file: final.callPackage file { }) packageFiles;

  flake.modules.nixos.base.nixpkgs.overlays = [ inputs.self.overlays.default ];

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      # A desktop host's package set, so these are the exact builds hosts install.
      hostPkgs = inputs.self.nixosConfigurations.shama.pkgs;
    in
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") (
        lib.filterAttrs (_: lib.meta.availableOn hostPkgs.stdenv.hostPlatform) (
          lib.mapAttrs (name: _: hostPkgs.${name}) packageFiles
        )
      );

      # Builds the packages in CI, which pushes them to attic.
      checks.packages = pkgs.symlinkJoin {
        name = "packages";
        paths = builtins.attrValues config.packages;
      };
    };
}
