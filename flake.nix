{
  description = "dendritic homelab configuration";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

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
    picolimbo.url = "github:wongcallum/PicoLimbo/nix";
    microvm.url = "github:astro/microvm.nix";
    flux.url = "github:IogaMaster/flux";

    # https://github.com/deniz-blue/mcman/pull/145
    flux.inputs.mcman.url = "github:wongcallum/mcman/fix/papermc-channels";

    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
    prism-tower.inputs.nixpkgs.follows = "nixpkgs";
    picolimbo.inputs.nixpkgs.follows = "nixpkgs";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
    flux.inputs.nixpkgs.follows = "nixpkgs";
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
