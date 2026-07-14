{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        lobehub-desktop = pkgs.callPackage ../../packages/lobehub-desktop { };
        kinochrome = pkgs.callPackage ../../packages/kinochrome { };
        chainner = pkgs.callPackage ../../packages/chainner { };
      };
    };
}
