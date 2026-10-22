{ inputs, ... }:
{
  flake.modules.nixos.nix-monitored =
    { pkgs, ... }:
    {
      imports = [
        inputs.nix-monitored.nixosModules.default
        inputs.self.modules.nixos.nix-output-monitor
      ];

      nix.monitored = {
        enable = true;
        notify = false;
        # workaround: nix-monitored-completions
        package = pkgs.nix-monitored.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../patches/nix-monitored-completions.patch
          ];
        });
      };
    };
}
