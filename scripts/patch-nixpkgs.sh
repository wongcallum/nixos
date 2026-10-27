#!/usr/bin/env nix
#! nix shell nixpkgs#ghcherry nixpkgs#jq --command bash
set -euo pipefail

nixpkgs_rev=$(nix flake metadata --json \
  | jq -er '.locks.nodes."unstable-upstream".locked.rev')

# 17df2f40 (xnviewmp desktop entry, rebased onto 2026-10-08 unstable)
# workaround: xnviewmp-desktop-entry
# PR 577437 (ipp-usb: migrate off the obsolete avahi publish options)
# workaround: ipp-usb-avahi-settings
# PR 576762 (cloudflared: 2026.10.1 -> 2026.10.3)
# workaround: cloudflared-2026-10-2
ghcherry --target wongcallum/nixpkgs@patched \
  --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
  wongcallum/nixpkgs/17df2f40207d9d68bf8b45ca3d6eb67f9b6dff7e \
  NixOS/nixpkgs#577437 \
  NixOS/nixpkgs#576762
  # ^ include commits, branches, or PRs https://github.com/PerchunPak/ghcherry
  # remember to include backslashes and never cherry-pick a merge commit!

nix flake update unstable
