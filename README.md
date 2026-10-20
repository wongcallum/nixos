# NixOS

Configuration for my homelab that attempts to follow the Dendritic pattern.

Structure ~~copied from~~ inspired by https://github.com/HarrisonCentner/nixconfig

## Check flake

`nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel` for one host, or

`nix flake check --no-build` for the entire flake.

## Deploy (rebuild)

`nix develop --command deploy .#{{host}}` (the devshell's `deploy` always passes `--skip-checks`)

## Deploy (install)

`nixos-anywhere --flake .#{{host}} --target-host {{user@hostname}}`

or, https://github.com/nix-community/disko/blob/master/docs/quickstart.md

### Initialise a new host

Create `hosts/nixos/{{host}}/default.nix`; `hosts/default.nix` turns it into `nixosConfigurations.{{host}}`.
Keep hardware settings inline in `default.nix` and disk layout in `_disko.nix`.
Set `flake.nixpkgs.{{host}} = "unstable";` if the host should follow unstable.

Add `{{host}}` to `ciHosts` in `modules/flake/checks.nix` so CI builds it and `deploy-schema` covers it.

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
nixos-anywhere --flake .#{{host}} --extra-files "$temp" --target-host {{user@hostname}}
rm -r "$temp"
```

## Installer

`nix build .#nixosConfigurations.{{minimal-iso|kde-iso}}.config.system.build.isoImage`

To make the attic cache accessible, pass a reusable, ephemeral, short-expiry auth key:

```bash
TS_AUTHKEY=tskey-auth-... nix build --impure .#nixosConfigurations.minimal-iso.config.system.build.isoImage
```

The installer then enrols itself on boot with `--state=mem:`.
However, the key is visible in the Nix store, so this must be treated as sensitive.

## Edit secrets

`sops ../nixos-secrets/secrets.yaml`

Remember to `nix flake update secrets`

## Add new sops host

```bash
ssh-to-age -i /path/to/new/host/.ssh/id_ed25519.pub
nvim ../nixos-secrets/.sops.yaml # add the new key
sops updatekeys ../nixos-secrets/secrets.yaml
```

Remember to `nix flake update secrets`

## Patch nixpkgs
```bash
nvim scripts/patch-nixpkgs.sh # add commits/branches/PRs
GITHUB_TOKEN=$(gh auth token) ./scripts/patch-nixpkgs.sh
```

