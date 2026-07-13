{ inputs, ... }:
{
  flake.modules.nixos.cryptomatord = {
    imports = [ inputs.cryptomatord.nixosModules.default ];

    services.cryptomatord.enable = true;
  };
}
