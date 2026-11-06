{
  flake.modules.nixos.helium =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.helium
      ];
    };
}
