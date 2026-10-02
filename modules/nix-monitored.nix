{ inputs, ... }:
{
  flake.modules.nixos.nix-monitored =
    { pkgs, ... }:
    {
      imports = [ inputs.nix-monitored.nixosModules.default ];

      nix.monitored = {
        enable = true;
        notify = false;
        # workaround: https://github.com/wongcallum/nixos/issues/84
        package = pkgs.nix-monitored.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../patches/nix-monitored-completions.patch
          ];
        });
      };
    };
}
