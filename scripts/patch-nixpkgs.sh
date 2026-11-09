#!/usr/bin/env nix
#! nix shell nixpkgs#ghcherry nixpkgs#jq --command bash
set -euo pipefail

nixpkgs_rev=$(nix flake metadata --json \
  | jq -er '.locks.nodes."unstable-upstream".locked.rev')

# 17df2f40: xnviewmp desktop entry
# workaround: xnviewmp-desktop-entry
# 585084: tsukimi aws-lc
# workaround: tsukimi-aws-lc
# 585883: zapfast system openssl and sqlcipher
# workaround: zapfast-system-libs
ghcherry --target wongcallum/nixpkgs@patched \
  --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
  wongcallum/nixpkgs/17df2f40207d9d68bf8b45ca3d6eb67f9b6dff7e \
  NixOS/nixpkgs#585084 \
  NixOS/nixpkgs#585883

nix flake update unstable
