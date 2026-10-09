#!/usr/bin/env -S nix shell nixpkgs#ghcherry nixpkgs#jq --command bash
set -euo pipefail

nixpkgs_rev=$(nix flake metadata --json \
  | jq -er '.locks.nodes."unstable-upstream".locked.rev')

# 17df2f40 (xnviewmp desktop entry, rebased onto 2026-10-08 unstable)
# workaround: xnviewmp-desktop-entry
ghcherry --target wongcallum/nixpkgs@patched \
  --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
  wongcallum/nixpkgs/17df2f40207d9d68bf8b45ca3d6eb67f9b6dff7e
  # ^ include commits, branches, or PRs https://github.com/PerchunPak/ghcherry
  # remember to include backslashes and never cherry-pick a merge commit!

nix flake update unstable
