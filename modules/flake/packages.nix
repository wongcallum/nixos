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
      openscq30 = unstablePkgs.callPackage ../../packages/openscq30 {
        craneLib = inputs.crane.mkLib unstablePkgs;
        src = inputs.openscq30;
      };
    in
    {
      packages = {
        lobehub-desktop = unstablePkgs.callPackage ../../packages/lobehub-desktop { };
        kinochrome = unstablePkgs.callPackage ../../packages/kinochrome { };
        chainner = unstablePkgs.callPackage ../../packages/chainner { };
        inherit (openscq30) openscq30-cli openscq30-gui;
      };

      # Builds the packages in CI, which pushes them to attic.
      checks.packages = pkgs.symlinkJoin {
        name = "packages";
        paths = builtins.attrValues config.packages;
      };
    };
}
