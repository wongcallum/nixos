#!/usr/bin/env -S nix shell nixpkgs#ghcherry nixpkgs#jq --command bash
set -euo pipefail

nixpkgs_rev=$(nix flake metadata --json \
  | jq -er '.locks.nodes."unstable-upstream".locked.rev')

ghcherry --target wongcallum/nixpkgs@patched \
  --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
  wongcallum/nixpkgs/6532eb6b9d9afa0911e333ee197eb30d9716fdf9
  # ^ include commits, branches, or PRs https://github.com/PerchunPak/ghcherry

nix flake update unstable
