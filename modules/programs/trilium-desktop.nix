{
  flake.modules.nixos.trilium-desktop =
    { pkgs, ... }:
    {
      # Use nixpkgs' prebuilt binary package. The upstream Trilium flake builds
      # from source via pnpm2nix IFD, which breaks `nix flake check --no-build`.
      environment.systemPackages = [ pkgs.trilium-desktop ];
    };
}
