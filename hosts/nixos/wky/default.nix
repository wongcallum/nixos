{ inputs, ... }:
{
  flake.modules.nixos."hosts/nixos/wky" = {
    imports = [
      ./_configuration.nix

      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.backupFileExtension = "backup";

        home-manager.users.callum = ./_home.nix;
      }
    ];

    _module.args.inputs = inputs;
  };
}
