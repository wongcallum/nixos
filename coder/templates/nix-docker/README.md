# Nix Docker template

This Coder template creates an Ubuntu Docker workspace with a pinned,
single-user Nix installation. The home directory and `/nix` store are backed
by per-workspace Docker volumes, so Nix profiles and packages survive a
workspace stop/start cycle.

The template is intended for the Coder deployment on `liz`:

- users access Coder at `https://coder.7sref`;
- workspace containers reach the Coder service at `http://10.0.0.3:3000`;
- the Docker provider uses the Docker daemon inside `vm-coder`.

## Publish

After logging in with the Coder CLI:

```sh
coder login https://coder.7sref
coder templates push nix-docker
```

Then create a workspace from the `nix-docker` template in the dashboard or
with:

```sh
coder create --template nix-docker nix-dev
```

## Workspace tools

The agent startup script installs the default package from `build/flake.nix`
into the coder user's Nix profile.

General tooling comes from `nixos-26.05`. The `codex` CLI instead comes from
the `llm-agents.nix` input, which is deliberately not following `nixpkgs`:
Numtide's cache only has binaries for their own nixpkgs revision, and a cache
miss means compiling the Codex Rust tree inside the workspace. The image adds
that substituter to `/etc/nix/nix.conf`.

## Signing in to Codex

`~/.codex/auth.json` is not bound to a host, so sign in once and hand the file
to every workspace:

```sh
codex login --device-auth
coder secret create codex-auth --file '~/.codex/auth.json' < ~/.codex/auth.json
```

The value comes from stdin; `--file` is the destination *inside* the
workspace, so quote the tilde to stop the local shell expanding it. Coder
writes file secrets before the startup script runs. Refreshed tokens stay in
the workspace and do not flow back, so `coder secret update codex-auth` when
the stored copy goes stale.
