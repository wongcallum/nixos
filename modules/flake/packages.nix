{
  perSystem =
    { pkgs, ... }:
    {
      packages.lobehub-desktop = pkgs.callPackage ../../packages/lobehub-desktop { };
    };
}
