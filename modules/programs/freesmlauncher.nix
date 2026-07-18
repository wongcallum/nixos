{ inputs, ... }:
{
  flake.modules.nixos.freesmlauncher =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [ inputs.freesmlauncher.overlays.default ];

      environment.systemPackages = [ pkgs.freesmlauncher ];
    };
}
