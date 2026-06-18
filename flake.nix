{
  description = "dendritic homelab configuration";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # best practice: do not mix stable and unstable on the same system
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    unstable-upstream.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:wongcallum/nixpkgs/patched";

    secrets = {
      url = "git+ssh://git@github.com/wongcallum/nixos-secrets.git?shallow=1";
      flake = false;
    };

    deploy-rs.url = "github:serokell/deploy-rs";
    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    prism-tower.url = "github:wongcallum/prism-tower";
    picolimbo.url = "github:Quozul/PicoLimbo";
    microvm.url = "github:astro/microvm.nix";
    ghostty.url = "github:ghostty-org/ghostty"; # don't follow nixpkgs to use their cachix
    zed.url = "github:wongcallum/zed/wayland-ext-background-effect";

    flux = {
      url = "github:IogaMaster/flux";
      inputs.nixpkgs.follows = "nixpkgs";
      # flux's flake.lock doesn't have my fix yet
      inputs.mcman.url = "github:deniz-blue/mcman/2665efb902631f7a98e0679ac7ed4998e6540022";
    };

    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
    prism-tower.inputs.nixpkgs.follows = "nixpkgs";
    picolimbo.inputs.nixpkgs.follows = "nixpkgs";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        (inputs.import-tree [
          ./modules
          ./hosts
        ])
      ];
    };
}
