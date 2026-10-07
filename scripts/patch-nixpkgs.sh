#!/usr/bin/env -S nix shell nixpkgs#ghcherry nixpkgs#jq --command bash
set -euo pipefail

nixpkgs_rev=$(nix flake metadata --json \
  | jq -er '.locks.nodes."unstable-upstream".locked.rev')

# 8c62da34 (xnviewmp desktop entry)
# workaround: xnviewmp-desktop-entry
ghcherry --target wongcallum/nixpkgs@patched \
  --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
  wongcallum/nixpkgs/8c62da340a74f0f1403fdf1deae96f11e2e0f860
  # ^ include commits, branches, or PRs https://github.com/PerchunPak/ghcherry
  # remember to include backslashes and never cherry-pick a merge commit!

nix flake update unstable
