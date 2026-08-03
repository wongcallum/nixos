{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      openscq30Pkgs = inputs.unstable.legacyPackages.${system};
      openscq30 = openscq30Pkgs.callPackage ../../packages/openscq30 {
        craneLib = inputs.crane.mkLib openscq30Pkgs;
        src = inputs.openscq30;
      };
    in
    {
      packages = {
        lobehub-desktop = pkgs.callPackage ../../packages/lobehub-desktop { };
        kinochrome = pkgs.callPackage ../../packages/kinochrome { };
        chainner = pkgs.callPackage ../../packages/chainner { };
        inherit (openscq30) openscq30-cli openscq30-gui;
      };
    };
}
