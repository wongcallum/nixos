{
  description = "dendritic homelab configuration";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    unstable-upstream.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:wongcallum/nixpkgs/patched";

    secrets = {
      url = "git+ssh://git@github.com/wongcallum/nixos-secrets.git?shallow=1";
      flake = false;
    };

    # `follows = ""` drops inputs only used by upstream dev shells, checks and formatters.

    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.home-manager.follows = "";
      inputs.flake-schemas.follows = "";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "";
    };
    nixbot = {
      url = "github:Mic92/nixbot";
      inputs.nixpkgs.follows = "unstable-upstream";
      inputs.treefmt-nix.follows = "";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "";
    };
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    prism-tower = {
      url = "github:wongcallum/prism-tower";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-monitored = {
      url = "github:ners/nix-monitored";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-output-monitor = {
      url = "github:wongcallum/nix-output-monitor/feat/program-status";
      inputs.nixpkgs.follows = "unstable";
      inputs.git-hooks.follows = "";
    };
    nix-discord-rpc = {
      url = "github:wongcallum/nix-discord-rpc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cryptomatord = {
      url = "github:wongcallum/cryptomatord";
      inputs.nixpkgs.follows = "unstable";
    };
    freesmlauncher = {
      url = "github:wongcallum/FreesmLauncher/multi-modrinth";
      inputs.nixpkgs.follows = "unstable";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
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
