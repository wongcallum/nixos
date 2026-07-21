{ inputs, ... }:
{
  # Zed from my fork (Wayland ext-background-effect blur patch), built via the
  # fork's own crane flake (its nix/build.nix) instead of nixpkgs' buildRustPackage.
  #
  # Why crane: it splits the build into a cached `buildDepsOnly` derivation and the
  # final `buildPackage`. Editing the fork's own source without touching Cargo.lock
  # reuses the compiled dependency artifacts instead of recompiling every crate --
  # which the previous buildRustPackage approach did on every source change.
  #
  # Why this is safe for `nix flake check --no-build` on CI: this crane version is
  # IFD-free. Its git-dependency vendoring resolves crate names at *build* time
  # (`cargo metadata` inside `downloadCargoPackageFromGit`) rather than reading them
  # from a fetched derivation output at eval time, and `mkDummySrc`'s `readDir` only
  # touches the already-realized flake-input source. Verified on a clean store that
  #   nix eval --option allow-import-from-derivation false \
  #     .#nixosConfigurations.shama.config.system.build.toplevel.drvPath
  # succeeds, i.e. evaluation never forces a build.
  #
  # The overlay's `mkZed final` builds against our own nixpkgs (shama's `unstable`),
  # pulling crane/rust-overlay from the zed flake's locked inputs. No vendor hash to
  # maintain -- crane vendors straight from the fork's Cargo.lock.
  flake.modules.nixos.zed =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [ inputs.zed.overlays.default ];
      environment.systemPackages = [ pkgs.zed-editor ];
    };
}
