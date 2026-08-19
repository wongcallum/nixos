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

Baseline tools can be added to `build/Dockerfile`. Packages installed later
with Nix are persisted in the workspace's `/nix` volume; that volume can grow
substantially, so remove abandoned workspaces when they are no longer needed.
