{ inputs, ... }:
let
  # prevent CPU spike and journal flood due to bug described in discussion #13267
  patchGhostty =
    ghostty:
    ghostty.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./ghostty-open-drain-busyloop.patch ];
    });
in
{
  perSystem =
    { system, ... }:
    {
      packages.ghostty = patchGhostty inputs.ghostty.packages.${system}.default;
    };

  flake.modules.nixos.ghostty =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (patchGhostty inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default)
      ];
    };
}
