# NixOS

Configuration for my homelab that attempts to follow the Dendritic pattern.

Structure ~~copied from~~ inspired by https://github.com/HarrisonCentner/nixconfig

## Check flake

`nix flake check`

## Deploy (rebuild)

`nix run github:serokell/deploy-rs -- .#{{host}}`

## Deploy (install)

`nix run github:nix-community/nixos-anywhere -- --flake .#{{host}} --target-host {{user@hostname}}`

or, https://github.com/nix-community/disko/blob/master/docs/quickstart.md

## Edit secrets

`nix run nixpkgs#sops secrets/secrets.yaml`

## Add new sops host

Edit sops.yaml, and then:
`nix run nixpkgs#sops updatekeys secrets/secrets.yaml`
