# NixOS

Configuration for my homelab, following the Dendritic pattern.

The structure is ~~copied from~~ inspired by https://github.com/HarrisonCentner/nixconfig

## Check the flake

Build one host with `nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel`, or check the whole flake with `nix flake check --no-build`.

## Deploy a rebuild

`nix develop --command deploy .#{{host}}`

The devshell's `deploy` always passes `--skip-checks`.

## Install a host

`nixos-anywhere --flake .#{{host}} --target-host {{user@hostname}}`

Or follow the [disko quickstart](https://github.com/nix-community/disko/blob/master/docs/quickstart.md).

### Initialise a new host

Create `hosts/nixos/{{host}}/default.nix`. `hosts/default.nix` turns it into `nixosConfigurations.{{host}}`.
Keep hardware settings inline in `default.nix` and the disk layout in `_disko.nix`.
Set `flake.nixpkgs.{{host}} = "unstable";` if the host should follow unstable.

Add `{{host}}` to `ciHosts` in `modules/flake/checks.nix` so CI builds it and `deploy-schema` covers it.

### Set up sops on a new host

Run `./scripts/new-sops-host.nu`.

#### Manual steps

```bash
set -gx temp $(mktemp -d) # or export in bash

# use $temp/etc/ssh if the host has no impermanence
install -d -m 0755 "$temp/persist/etc/ssh"
ssh-keygen -t ed25519 -N "" -C "root@{{host}}" -f "$temp/persist/etc/ssh/ssh_host_ed25519_key"
chmod 0600 "$temp/persist/etc/ssh/ssh_host_ed25519_key"
```

Then [add the new sops host](#add-a-new-sops-host) and install:

```bash
nixos-anywhere --flake .#{{host}} --extra-files "$temp" --target-host {{user@hostname}}
rm -r "$temp"
```

## Installer

`nix build .#nixosConfigurations.{{minimal-iso|kde-iso}}.config.system.build.isoImage`

To let the installer join the tailnet and reach the attic cache, add a Tailscale OAuth client secret to the built image. The client needs the auth key write scope and `tag:installer`.

```bash
set -gx TS_OAUTH_SECRET tskey-client-... # optional

scripts/iso-add-tailscale-key.sh result/iso/nixos-*.iso
# writes nixos-<version>-x86_64-linux-tskey.iso to the current directory
```

The installer uses strict DNS-over-TLS to Cloudflare. To allow plain DNS:

```bash
mkdir -p /run/systemd/resolved.conf.d
printf '[Resolve]\nDNSOverTLS=no\n' >/run/systemd/resolved.conf.d/plain.conf
systemctl restart systemd-resolved
```

## Edit secrets

`sops ../nixos-secrets/secrets.yaml`

Then run `nix flake update secrets`.

## Add a new sops host

```bash
ssh-to-age -i /path/to/new/host/.ssh/id_ed25519.pub
nvim ../nixos-secrets/.sops.yaml # add the new key
sops updatekeys ../nixos-secrets/secrets.yaml
```

Then run `nix flake update secrets`.

## Patch nixpkgs

```bash
nvim scripts/patch-nixpkgs.sh # add commits, branches or PRs
GITHUB_TOKEN=$(gh auth token) ./scripts/patch-nixpkgs.sh
```
