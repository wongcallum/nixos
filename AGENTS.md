# AGENTS.md

## Guardrails

- You can't deploy; ask the user to.
- Commit and amend whenever it makes sense, directly to master unless told otherwise.
- Secrets: leave `inputs.secrets` and its repository untouched. Ask the user to make any required secret changes.
- Never link issues or PRs in other repos (`owner/repo#123` or URLs); GitHub creates backlinks on them. Describe them in prose.
- Store inspection: follow known `/nix/store/...` paths; never scan the whole store.

## Style

- Respond tersely.
- After committing, start your response with "Commit: `<hash>`" (append "(amended)" if you did). Don't mention push or deploy status.
- Commit messages: about 50 characters, imperative mood, formatted `host: change`. Drop the prefix if the change covers no host or multiple hosts. If more is needed, add succinct dot points.
- By default, write no comments. Only comment behaviour that would surprise a competent reader of the code. Keep it to a line or two.

## Workflow

1. Stage new `.nix` files with `git add` before evaluating; `import-tree` evaluates the Git source.
2. For each affected host, build `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
3. Verify the change by inspecting the generated unit/file (follow `/nix/store/...` paths directly) or comparing `nix eval` of the changed option.
4. Run `nix develop --command bash -c 'treefmt; statix check .; deadnix --fail .'`.
5. Only when the change touches shared modules, `modules/flake/` or inputs, run `nix flake check --no-build`. `--no-build` is mandatory; without it every host's toplevel is realised.

**Low-memory agents:** evaluation peaks around 3.5 GiB per host and 9 GiB for the flake check. If you can't evaluate locally, skip steps 2, 3 and 5: push a branch to `wongcallum/nixos` (not a fork) and open a draft PR. nixbot builds every host and the lint workflow covers step 4. Mark it ready once all checks pass.

## Architecture

Dendritic flake (flake-parts + `import-tree`). Files under `modules/` and `hosts/` are auto-imported and declare `flake.modules.<class>.<name>`, where class is `nixos` or `generic` (reusable across classes).

Before structuring a new feature or refactoring feature composition, read `.agents/skills/dendritic-aspects/SKILL.md`. Compose modules with `lib.mkMerge`, not `//`.

### Hosts

`hosts/default.nix` creates `nixosConfigurations.<hostname>` for each directory under `hosts/nixos/`, with `base`, `global` and `flake.modules.nixos."hosts/nixos/<hostname>"`.

A host's `default.nix` imports features from `config.flake.modules.nixos` and holds general host settings. `_`-prefixed files are plain NixOS modules for self-contained host concerns, imported by the host module.

- **Shadowed `config`:** when host settings need NixOS module arguments, capture `let inherit (config.flake.modules) nixos;` in the outer scope first, as in `hosts/nixos/liz/default.nix`.
- **Package set:** `flake.nixpkgs.<hostname> = "<input>"`; defaults to stable `nixpkgs`.

### Feature conventions

- **Feature toggles:** define `options.modules.*` in `modules/global.nix` and gate features on them.
- **Containers:** `config.utils.mkContainer` (`modules/utils.nix`) for Quadlet containers.
- **Persistent state:** root is rolled back on boot (`impermanence-zfs` / `impermanence-btrfs`). Use `config.utils.dataDir "<name>"` for service data and `config.utils.cacheDir "<name>"` for regenerable caches; add other state to `environment.persistence.${config.modules.persistence.persistDir}`.
- **microVM networking:** `microvmLib.mkHostNetworking` and `microvmLib.mkGuestModule` (`modules/lib/microvm.nix`).
- **Users:** `self.factory.user <name> <isAdmin> <useSopsPassword>` (`modules/users/factory.nix`) plus a per-user module.
- **Web services:** add an entry to the registry in `modules/services/gateway.nix`; Caddy and `prism-tower` derive their config from it.

### Workarounds

Every local workaround for an upstream problem (patches, overlays, `overrideAttrs`, pins, input overrides, forks, disabling a broken feature) has an entry in `modules/workarounds.nix`.

- **Adding:** set `upstream` (link or "not filed"), `done` (when it can be removed) and, only if deleting the marked code isn't enough, `cleanup`. Mark the code with `# workaround: <id>`. If `done` can be evaluated from locked inputs, add a `fixed` check against `pkgsFor <host>` or the raw input, never a host's `pkgs` (which includes the workaround).
- **Checking:** `scripts/workarounds.sh` lists them by urgency. For `manual` ones, follow `.agents/skills/check-workarounds/SKILL.md`.
- **Removing:** delete the marked code and its entry. The `workarounds` flake check fails once a `fixed` check holds or an entry marks no code.

### nixpkgs patches

Prefer cherry-picking an upstream fix: add its PR or commit to `scripts/patch-nixpkgs.sh` and run it locally. Use a local overlay only when that isn't possible.

Pass `ghcherry` a PR reference or individual commit hashes, never a merge commit (its `NixOS#NNNNN` message causes GitHub to create cross-references).
