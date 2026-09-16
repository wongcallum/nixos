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
