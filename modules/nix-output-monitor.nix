# my fork reports build progress to the terminal (OSC 7501)
{ inputs, ... }:
{
  flake.modules.nixos.nix-output-monitor =
    { pkgs, ... }:
    {
      # imported by both desktop and nix-monitored; the key lets NixOS dedupe it
      key = "nix-output-monitor";
      nixpkgs.overlays = [ inputs.nix-output-monitor.overlays.default ];
      environment.systemPackages = [ pkgs.nix-output-monitor ];
    };
}
