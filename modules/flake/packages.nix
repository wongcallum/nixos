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
      # GUI packages dlopen the host's GPU drivers (/run/opengl-driver), so they
      # must share glibc with the hosts running them, which are on unstable
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
        zapfast = unstablePkgs.callPackage ../../packages/zapfast { };
        inherit (openscq30) openscq30-cli openscq30-gui;
      };

      # push packages to attic
      checks.packages = pkgs.symlinkJoin {
        name = "packages";
        paths = builtins.attrValues config.packages;
      };
    };
}
