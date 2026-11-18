#!/usr/bin/env bash
# Shows the config revision each host is running, relative to HEAD.
# liz's guests that restart with its closure are reported from liz.
#   scripts/revs.sh [host...]
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

if (($#)); then
  hosts=("$@")
else
  mapfile -t hosts < <(nix eval --raw .#deploy.nodes \
    --apply 'nodes: builtins.concatStringsSep "\n" (builtins.attrNames nodes)')
fi

declare -A follows
while IFS=$'\t' read -r guest parent; do
  follows[$guest]=$parent
done < <(nix eval --raw .#vmFollows --apply \
  'f: builtins.concatStringsSep "" (builtins.attrValues (builtins.mapAttrs (g: p: "${g}\t${p}\n") f))')

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

query=(/run/current-system/sw/bin/nixos-version --configuration-revision)
declare -A queried
for host in "${hosts[@]}"; do
  target=${follows[$host]:-$host}
  [[ -n ${queried[$target]-} ]] && continue
  queried[$target]=1
  host=$target
  if [[ $host == "$(hostname)" ]]; then
    "${query[@]}"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "${query[@]}"
  fi >"$tmp/$host" 2>"$tmp/$host.err" &
done
wait

for host in "${hosts[@]}"; do
  target=${follows[$host]:-$host}
  via=""
  [[ $target != "$host" ]] && via=" (via $target)"
  rev=$(<"$tmp/$target")
  if [[ -z $rev ]]; then
    if grep -q 'revision is unknown' "$tmp/$target.err"; then
      status="unknown (deployed before revisions were recorded)"
    else
      status="unreachable"
    fi
    printf '%s\t-\t%s\n' "$host" "$status$via"
    continue
  fi
  commit=${rev%-dirty}
  dirty=${rev:${#commit}}
  if ! git cat-file -e "$commit^{commit}" 2>/dev/null; then
    printf '%s\t%s\t%s\n' "$host" "${commit:0:7}$dirty" "not in this repo$via"
    continue
  fi
  behind=$(git rev-list --count "$commit..HEAD")
  ahead=$(git rev-list --count "HEAD..$commit")
  if ((behind == 0 && ahead == 0)); then
    status="current"
  else
    status=""
    ((behind)) && status="$behind behind"
    ((ahead)) && status="${status:+$status, }$ahead not in HEAD"
  fi
  printf '%s\t%s\t%s\t%s\n' "$host" "${commit:0:7}$dirty" "$status$via" \
    "$(git log -1 --format='%cs %s' "$commit")"
done | column -t -s $'\t'
