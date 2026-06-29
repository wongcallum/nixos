# AGENTS.md

- Do NOT deploy automatically, unless explicitly authorised.
- Do not commit your changes unless explicitly asked.
- Do not touch the secrets repository or input, just prompt the user to modify them when necessary.
- Run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` during iterative changes.
- Run `nix flake check --no-build` at the very end before finishing.
- Do not run `nix flake check` without `--no-build`: it realises every host's `toplevel` and can unnecessarily copy multi-gigabyte closures back to the local store.
- Run the lint commands at the very end before committing: `nix develop --command bash -c 'nixfmt-tree; statix check .; deadnix --fail .`
- Run `git add <untracked files>` whenever a new Nix file is created, flakes ignore untracked files.
- Use idiomatic Nix, be inspired by nixpkgs.
- Don't grep from the entire /nix/store.

## Architecture

This is a **Dendritic pattern** flake built on **flake-parts** + **import-tree**. Every `.nix` file under `modules/` and `hosts/` is auto-imported as a flake-parts module.

Features are declared as `flake.modules.<class>.<name>`:

- `nixos` — NixOS system modules (the common case).
- `generic` — values/options reusable across classes (e.g. `utils`).

For full pattern catalog (Simple, Multi-Context, Inheritance, Conditional, Collector, Constants, DRY, Factory) see `.agents/skills/dendritic-aspects/SKILL.md`. Always use `lib.mkMerge`, never `//`.

`hosts/default.nix` scans `hosts/nixos/<hostname>/` directories and produces a `nixosConfigurations.<hostname>` for each. Every host automatically gets the `base` and `global` modules plus its own module (`flake.modules.nixos."hosts/nixos/<hostname>"`).

A host module is itself a Dendritic feature that **imports other features** (e.g. `persistence`, `sops`, `ssh`, `tailscale`, `gateway`, …) from `config.flake.modules.nixos.<name>`. See `hosts/nixos/liz/default.nix` for the canonical example.

Per-host files prefixed with `_` (e.g. `_configuration.nix`, `_disko.nix`, `_networking.nix`, `_home.nix`) are **regular NixOS modules**, not flake-parts modules — convention is to keep host-specific config out of the flake module graph.

A host can opt into `unstable` (or any other input) by setting `flake.nixpkgs.<hostname> = "unstable"` in its `default.nix`. `hosts/default.nix` reads this to pick which `inputs.<name>.lib.nixosSystem` builds the host. Default is `nixpkgs` (stable).

### Patching nixpkgs

The `unstable` input points to `wongcallum/nixpkgs@patched`, a fork branch maintained by `gh-cherry-pick`. Patches are cherry-picked onto the upstream `nixos-unstable` rev. The upstream tracking input is `unstable-upstream`.

To add or update patches, update the script at `scripts/patch-nixpkgs.sh` and run it locally.
The `update-flake-lock` workflow automates this on weekly runs (requires `NIXPKGS_PAT` secret).

When cherry-picking from upstream nixpkgs PRs, use the individual commit hash, **not** the merge commit — merge commit messages contain `NixOS#NNNNN` which makes GitHub cross-reference the upstream PR on every push to the fork.

### Shared options and helpers

- `modules/global.nix` defines `options.modules.*` toggles (`ssh.enable`, `tailscale.enable`, container enable-flags, etc.) that features gate on.
- `modules/utils.nix` exposes `config.utils`:
  - `config.utils.persistDir` — `/persist` mount root.
  - `config.utils.dataDir "<name>"` — `/persist/data/<name>`, the conventional location for service state.
  - `config.utils.mkContainer { … }` — wrapper for quadlet containers with sane defaults (always-restart, PUID/PGID=1000, TZ).
- `modules/lib/microvm.nix` adds `microvmLib` to `_module.args` with `mkHostNetworking` / `mkGuestModule` for microVM host/guest plumbing on a 10.0.0.0/24 internal net.
- `modules/users/factory.nix` defines `self.factory.user <name> <isAdmin> <useSopsPassword>` — wire new users via this factory plus a per-user module under `modules/users/`.

### Reverse-proxy + dashboard registry

`modules/services/gateway.nix` exposes `modules.gateway.services.<key> = { name; domainName; addr; iconUrl; category; hidden; }`. Any feature can contribute entries to this registry (Collector pattern), and Caddy + `prism-tower` derive the reverse proxy and homepage from it. New web services should register themselves here rather than configuring Caddy directly. TLD comes from `modules.gateway.tld` (default `7sref`).

### Persistence model

Hosts using `impermanence-zfs` rollback `rpool/nixos/root@blank` on boot — anything outside `/persist` is wiped. Features that need state add directories/files to `environment.persistence.${config.modules.persistence.persistDir}` (see `modules/ssh.nix` and `modules/tailscale.nix` for the pattern). Service data dirs should use `config.utils.dataDir`.

### Secrets

`inputs.secrets` points to a private `git+ssh` sibling repo (`../nixos-secrets`). `modules/sops.nix` wires `sops-nix` with `defaultSopsFile = ${secrets}/secrets.yaml` and decrypts using each host's `ssh_host_ed25519_key` under `persistDir`. Do not modify the secrets repo or input, prompt the user.

## CI

GitHub Actions runs on every PR and on `master`:

- `check.yml` — `nix flake check --no-build --show-trace` (needs the secrets deploy key).
- `lint.yml` — `nixfmt-tree --ci`, `statix check .`, `deadnix --fail .`.
- `build-iso.yml` — builds `minimal-iso` on changes to `hosts/iso/**` and publishes a release.
- `update-flake-lock.yml` — weekly: rebases `wongcallum/nixpkgs@patched` via `gh-cherry-pick`, then updates all flake inputs and opens a PR.
