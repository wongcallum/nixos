#!/usr/bin/env -S nix shell nixpkgs#gh-cherry-pick nixpkgs#jq --command bash
set -euo pipefail

nixpkgs_rev=$(nix flake metadata --json \
  | jq -er '.locks.nodes."unstable-upstream".locked.rev')

gh-cherry-pick --target wongcallum/nixpkgs@patched \
  --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
  wongcallum/nixpkgs/6532eb6b9d9afa0911e333ee197eb30d9716fdf9 \
  NixOS/nixpkgs/df11c04eafb13f1f2913c198a24d603f9a7b2db9
  # ^ include commits, branches, or PRs https://github.com/PerchunPak/ghcherry

nix flake update unstable
