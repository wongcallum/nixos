{
  flake.modules.nixos.ghostty =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.ghostty ];
    };
}
