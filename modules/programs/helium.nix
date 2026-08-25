_: {
  flake.modules.nixos.helium =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.callPackage ../../packages/helium { }).helium
      ];
    };
}
