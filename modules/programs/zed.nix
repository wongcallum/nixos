{ inputs, ... }:
{
  # Zed from my fork (Wayland ext-background-effect blur patch), built on top of
  # nixpkgs' zed-editor rather than the fork's own crane flake. crane's
  # cleanCargoSource does a readDir IFD at eval time that `nix flake check
  # --no-build` refuses to substitute; buildRustPackage has no such IFD, so eval
  # stays cheap and CI needs no binary-cache prefetch.
  #
  # On every zed input bump, recompute the vendor hash (the fork's Cargo.lock
  # differs from upstream's) by building with lib.fakeHash:
  #   nix build --impure --expr 'let f = builtins.getFlake (toString ./.); in
  #     f.inputs.unstable.legacyPackages.x86_64-linux.rustPlatform.fetchCargoVendor {
  #       src = f.inputs.zed; name = "zed-editor-blur-vendor"; hash = f.inputs.unstable.legacyPackages.x86_64-linux.lib.fakeHash; }'
  # and copy the "got:" hash here.
  flake.modules.nixos.zed =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.zed-editor.overrideAttrs (old: {
          version = "${old.version}-blur";
          src = inputs.zed;
          # Build a fresh vendor dir from the fork's Cargo.lock. We can't reuse
          # `old.cargoDeps.overrideAttrs { src = ...; }` -- fetchCargoVendor's
          # staging stage is a fixed store reference, so that silently re-vendors
          # the upstream deps instead of the fork's.
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            src = inputs.zed;
            name = "zed-editor-blur-vendor";
            hash = "sha256-Nwg29Mfn/Ij+7F/kh7a/gD85AysOYyWYK2LRVrMpe7g=";
          };
        }))
      ];
    };
}
