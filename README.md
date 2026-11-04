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

### Set up secrets on a new host

```bash
set -gx temp $(mktemp -d) # or export in bash

# use $temp/etc/ssh if the host has no impermanence
install -d -m 0755 "$temp/persist/etc/ssh"
ssh-keygen -t ed25519 -N "" -C "root@{{host}}" -f "$temp/persist/etc/ssh/ssh_host_ed25519_key"
chmod 0600 "$temp/persist/etc/ssh/ssh_host_ed25519_key"
```

Then [add the new secrets host](#add-a-new-secrets-host) and install:

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

Declare the secret under `security.nix-secrets.secrets`, then, from the dev shell:

```bash
nix-secrets edit --flake .#{{host}} {{name}} # writes ../nixos-secrets/{{name}}.enc
```

Commit it in the secrets repo, then run `nix flake update secrets`.

## Add a new secrets host

Add the host's SSH public key to `hostKeys` in `modules/secrets.nix`. Each secret is encrypted to callum's keys and the hosts that enable it, so after changing which hosts use a secret, rekey it:

```bash
nix-secrets rekey --flake .#{{host}}
```

Commit the secrets repo, then run `nix flake update secrets`.

## Patch nixpkgs

```bash
nvim scripts/patch-nixpkgs.sh # add commits, branches or PRs
GITHUB_TOKEN=$(gh auth token) ./scripts/patch-nixpkgs.sh
```
