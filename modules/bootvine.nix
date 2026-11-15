{ inputs, ... }:
{
  flake.modules.nixos.bootvine = {
    imports = [ inputs.bootvine.nixosModules.default ];

    services.bootvine.enable = true;
    boot.consoleLogLevel = 3;
  };
}
