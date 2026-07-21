{ inputs, ... }:
{
  flake.modules.nixos.zed =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [ inputs.zed.overlays.default ];
      environment.systemPackages = [ pkgs.zed-editor ];
    };
}
