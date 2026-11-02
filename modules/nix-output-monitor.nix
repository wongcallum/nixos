# My fork reports build progress to the terminal with OSC 7501.
{ inputs, ... }:
{
  flake.modules.nixos.nix-output-monitor =
    { pkgs, ... }:
    {
      # desktop and nix-monitored both import this, and the key dedupes it.
      key = "nix-output-monitor";
      nixpkgs.overlays = [ inputs.nix-output-monitor.overlays.default ];
      environment.systemPackages = [ pkgs.nix-output-monitor ];
    };
}
