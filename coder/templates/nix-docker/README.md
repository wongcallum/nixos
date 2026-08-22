# Nix Docker template

This Coder template creates an Ubuntu Docker workspace with a pinned,
single-user Nix installation. The home directory and `/nix` store are backed
by per-workspace Docker volumes, so Nix profiles and packages survive a
workspace stop/start cycle.

## Publish

After logging in with the Coder CLI:

```sh
coder templates push nix-docker
```

Then create a workspace from the `nix-docker` template in the dashboard or
with:

```sh
coder create --template nix-docker nix-dev
```

## Upgrading workspace tools

The tool set is baked into the image at `/etc/coder/nix-environment`, so
upgrading means rebuilding the workspace onto a new image.

```sh
coder templates push nix-docker
coder update <workspace>
```

## Signing in to Codex

```sh
codex login --device-auth
coder secret create codex-auth --file '~/.codex/auth.json' < ~/.codex/auth.json

# when the stored oauth credentials expire:
coder secret update codex-auth
```
