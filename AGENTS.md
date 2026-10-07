# AGENTS.md

## Guardrails

- Deploy or commit only when explicitly requested.
- Secrets: leave `inputs.secrets` and its repository untouched. Ask the user to make any required secret changes.
- Store inspection: follow known `/nix/store/...` paths; never scan the whole store.

## Workflow

1. Before evaluating the flake, stage every new `.nix` file with `git add <path>`. `import-tree` evaluates the Git source, so untracked files appear as missing attributes.
2. For Nix changes, iterate per affected host with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
3. Verify each build in `result/` by inspecting the affected generated unit/file or comparing `nix eval` of the changed option. `result` is the built system closure; follow referenced `/nix/store/...` paths directly rather than under `result/`.
4. Before finishing, run `nix develop --command bash -c 'treefmt; statix check .; deadnix --fail .'`.
5. Finish with `nix flake check --no-build`. `--no-build` is mandatory: omitting it realises every host's toplevel and may copy multi-gigabyte closures into the local store.

**Low-memory agents:** evaluation peaks around 3.5 GiB per host and 9 GiB for the full flake check. An agent that cannot evaluate locally may skip steps 2, 3 and 5: push a branch to `wongcallum/nixos` (not a fork, whose PRs wait for approval) and open a draft pull request. nixbot evaluates and builds every host, and the lint workflow covers step 4. Mark the pull request ready only once all nixbot and lint checks pass.

## Architecture

This is a Dendritic flake built with flake-parts and `import-tree`. Feature files under `modules/` and `hosts/` are auto-imported and declare `flake.modules.<class>.<name>`:

- `nixos` — NixOS modules.
- `generic` — values and options reusable across classes.

**Dendritic design:** before structuring a new feature or refactoring feature composition, read `.agents/skills/dendritic-aspects/SKILL.md`. Compose modules with `lib.mkMerge` rather than `//`.

### Hosts

`hosts/default.nix` creates a `nixosConfigurations.<hostname>` for each directory under `hosts/nixos/`. Every host receives `base`, `global`, and its own `flake.modules.nixos."hosts/nixos/<hostname>"` module.

A host's `default.nix` imports reusable features from `config.flake.modules.nixos` and holds general host settings. Files prefixed with `_` are ordinary NixOS modules for self-contained host concerns; the host module imports them.

- **Shadowed `config`:** when host settings need NixOS module arguments, capture `nixos` in the outer flake-parts scope with `let inherit (config.flake.modules) nixos;` before defining the module function. Follow `hosts/nixos/liz/default.nix`.
- **Package set:** set `flake.nixpkgs.<hostname> = "<input>"` in the host's `default.nix`; the default is stable `nixpkgs`.

### Feature conventions

- **Feature toggles:** define shared `options.modules.*` toggles in `modules/global.nix`; gate features on them.
- **Containers:** use `config.utils.mkContainer` from `modules/utils.nix` for Quadlet containers.
- **Persistent state:** `impermanence-zfs` rolls `rpool/nixos/root@blank` back on boot. Use `config.utils.dataDir "<name>"` for service data and add other state to `environment.persistence.${config.modules.persistence.persistDir}`.
- **microVM networking:** use `microvmLib.mkHostNetworking` and `microvmLib.mkGuestModule` from `modules/lib/microvm.nix`.
- **Users:** use `self.factory.user <name> <isAdmin> <useSopsPassword>` from `modules/users/factory.nix` plus a per-user module.
- **Web services:** contribute an entry to the registry exposed by `modules/services/gateway.nix`; Caddy and `prism-tower` derive their configuration from it.

### Workarounds

Every local workaround for an upstream problem has an entry in `modules/workarounds.nix`. Workarounds include patches, `overrideAttrs`/overlays, version or source pins, input overrides, forks, and config that disables a broken feature.

- **Adding one:** add an entry with `upstream` (link, or "not filed"), `done` (when it can be removed) and, only if deleting the marked code isn't enough, `cleanup`. Mark the code with a `# workaround: <id>` comment. When `done` can be evaluated from the locked inputs, add a `fixed` check against `pkgsFor <host>` or the raw input, never a host's `pkgs`, which includes the workaround itself.
- **Checking:** `scripts/workarounds.sh` lists workarounds, most urgent first. To check `manual` ones, follow `.agents/skills/check-workarounds/SKILL.md`.
- **Removing one:** delete the marked code and its entry. The `workarounds` flake check fails once a `fixed` check holds, or when an entry marks no code.

### nixpkgs patches

Prefer a suitable upstream fix: add its PR or commit to `scripts/patch-nixpkgs.sh` and run the script locally. Use a local overlay only when no suitable upstream fix can be cherry-picked.

Pass `ghcherry` a PR reference or individual commit hashes, not a merge commit. Merge commit messages contain `NixOS#NNNNN`, which triggers unwanted GitHub cross-references on the fork.
