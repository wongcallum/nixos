{ inputs, ... }:
{
  flake.modules.nixos.freesmlauncher =
    { pkgs, lib, ... }:
    {
      nixpkgs.overlays = [ inputs.freesmlauncher.overlays.default ];

      environment.systemPackages = [
        # workaround: https://github.com/wongcallum/nixos/issues/77
        # https://github.com/FreesmTeam/FreesmLauncher/pull/233
        ((pkgs.freesmlauncher.override { jdks = [ ]; }).overrideAttrs (old: {
          qtWrapperArgs = builtins.filter (
            a: !lib.hasPrefix "--prefix FREESMLAUNCHER_JAVA_PATHS" a
          ) old.qtWrapperArgs;
        }))
      ];
    };
}
