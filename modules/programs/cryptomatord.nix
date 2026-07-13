{ inputs, ... }:
{
  flake.modules.nixos.cryptomatord = { pkgs, ... }: {
    imports = [ inputs.cryptomatord.nixosModules.default ];

    services.cryptomatord = {
      enable = true;
      extraPackages = [ pkgs.zenity ];
    };
  };
}
