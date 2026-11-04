{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      # GUI packages dlopen the hosts' GPU drivers, so they need the same glibc as
      # the hosts, which run unstable.
      unstablePkgs = import inputs.unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = {
        lobehub-desktop = unstablePkgs.callPackage ../../packages/lobehub-desktop { };
        kinochrome = unstablePkgs.callPackage ../../packages/kinochrome { };
        chainner = unstablePkgs.callPackage ../../packages/chainner { };
      };

      # Builds the packages in CI, which pushes them to attic.
      checks.packages = pkgs.symlinkJoin {
        name = "packages";
        paths = builtins.attrValues config.packages;
      };
    };
}
