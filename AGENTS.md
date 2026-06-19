# AGENTS.md

- Do NOT deploy automatically, unless explicitly authorised.
- Do not touch the secrets repository or input, just prompt the user to modify them when necessary.
- Do not commit your changes unless explicitly asked.
- Run `nix build '.#nixosConfigurations.<host>.config.system.build.toplevel'` during iterative changes.
- Run `nix flake check` at the very end before finishing.
- Run `git add <untracked files>` whenever Nix complains about "path does not exist".
- Use idiomatic Nix, be inspired by nixpkgs.
- Don't grep from the entire /nix/store.
