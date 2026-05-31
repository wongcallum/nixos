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

`nix run nixpkgs#sops ../nixos-secrets/secrets.yaml`

## Add new sops host

```bash
nix run nixpkgs#ssh-to-age -- -i /path/to/new/host/.ssh/id_ed25519.pub
nvim ../nixos-secrets/.sops.yaml # add the new key
nix run nixpkgs#sops -- updatekeys ../nixos-secrets/secrets.yaml
```

## Patch nixpkgs
```bash
nvim scripts/patch-nixpkgs.sh # add commits/branches/PRs
GITHUB_TOKEN=$(gh auth token) ./scripts/patch-nixpkgs.sh
```

