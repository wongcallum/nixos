# NixOS

Configuration for my homelab that attempts to follow the Dendritic pattern.

Structure ~~copied from~~ inspired by https://github.com/HarrisonCentner/nixconfig

## Check flake

`nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel` for one host, or

`nix flake check` for the entire flake

## Deploy (rebuild)

`nix run nixpkgs#deploy-rs -- .#{{host}}`

## Deploy (install)

`nix run nixpkgs#nixos-anywhere -- --flake .#{{host}} --target-host {{user@hostname}}`

or, https://github.com/nix-community/disko/blob/master/docs/quickstart.md

### Initialise a new host

Create a new `hosts/{{host}}/default.nix`, then import `./_configuration.nix`

Either manually create and fill in the file or pass in
`--generate-hardware-config nixos-generate-config hosts/{{host}}/_configuration.nix`
when running `nixos-anywhere`

### Sops on new host

NEW! run `./scripts/new-sops-host.nu`

#### Manual steps

```bash
set -gx temp $(mktemp -d) # or export in bash

# use just $temp/etc/ssh if host does not have impermanence
install -d -m 0755 "$temp/persist/etc/ssh"
ssh-keygen -t ed25519 -N "" -C "root@{{host}}" -f "$temp/persist/etc/ssh/ssh_host_ed25519_key"
chmod 0600 "$temp/persist/etc/ssh/ssh_host_ed25519_key"
```

[Add new sops host](#add-new-sops-host)

```bash
nix run nixpkgs#nixos-anywhere -- --flake .#{{host}} --extra-files "$temp" --target-host {{user@hostname}}
rm -r "$temp"
```

## Edit secrets

`nix run nixpkgs#sops ../nixos-secrets/secrets.yaml`

Remember to `nix flake update secrets`

## Add new sops host

```bash
nix run nixpkgs#ssh-to-age -- -i /path/to/new/host/.ssh/id_ed25519.pub
nvim ../nixos-secrets/.sops.yaml # add the new key
nix run nixpkgs#sops -- updatekeys ../nixos-secrets/secrets.yaml
```

Remember to `nix flake update secrets`

## Patch nixpkgs
```bash
nvim scripts/patch-nixpkgs.sh # add commits/branches/PRs
GITHUB_TOKEN=$(gh auth token) ./scripts/patch-nixpkgs.sh
```

