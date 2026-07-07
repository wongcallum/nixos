{ inputs, ... }:
{
  flake.modules.nixos.nix-monitored = {
    imports = [ inputs.nix-monitored.nixosModules.default ];

    nix.monitored.enable = true;
    nix.monitored.notify = false;
  };
}
