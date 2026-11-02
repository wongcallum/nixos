#!/usr/bin/env nix
#! nix shell nixpkgs#xorriso --command bash
# Usage: scripts/iso-add-tailscale-key.sh <in.iso> [out.iso]
# Secret from $TS_OAUTH_SECRET or a prompt. The output image is sensitive.
set -euo pipefail

target=/tailscale/oauth-secret

if (($# < 1 || $# > 2)); then
  echo "usage: $0 <in.iso> [out.iso]" >&2
  exit 2
fi
in=$1
out=${2:-$(basename "${in%.iso}")-tskey.iso}

if [[ ! -f $in ]]; then
  echo "$in: no such file" >&2
  exit 1
fi
if [[ -e $out ]]; then
  echo "$out already exists" >&2
  exit 1
fi

secret=${TS_OAUTH_SECRET-}
if [[ -z $secret ]]; then
  read -rsp "Tailscale OAuth client secret: " secret
  echo >&2
fi
if [[ $secret != tskey-client-* ]]; then
  echo "expected an OAuth client secret (tskey-client-...)" >&2
  exit 1
fi

umask 077
tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/iso-ts.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
printf '%s' "$secret" >"$tmp/oauth-secret"

# replay keeps the boot records and volume ID the initrd finds the ISO by
xorriso -no_rc \
  -indev "$in" \
  -outdev "$out" \
  -boot_image any replay \
  -map "$tmp/oauth-secret" "$target" \
  -chown 0 "$(dirname "$target")" "$target" -- \
  -chgrp 0 "$(dirname "$target")" "$target" -- \
  -chmod 0700 "$(dirname "$target")" -- \
  -chmod 0400 "$target" --

chmod 600 "$out"
echo "wrote $out" >&2
