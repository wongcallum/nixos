#!/usr/bin/env -S nix shell nixpkgs#jq --command bash
# Lists the workarounds in modules/workarounds.nix, most urgent first:
#   unmarked  the entry marks no code
#   fixed     its `fixed` check holds for the locked inputs, so remove it
#   manual    no `fixed` check; least recently checked first
#   pending   its `fixed` check doesn't hold yet
# After checking one by hand, record what you found with
#   scripts/workarounds.sh note <id> <finding>
# Notes live in the untracked .workarounds.json; the rest is recomputed.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

notes=.workarounds.json
[[ -s $notes ]] || echo '{}' >"$notes"

if [[ ${1-} == note ]]; then
  if (($# < 3)); then
    echo "usage: $0 note <id> <finding>" >&2
    exit 2
  fi
  id=$2
  shift 2
  if ! nix eval --json .#workarounds --apply builtins.attrNames \
    | jq -e --arg id "$id" 'index($id)' >/dev/null; then
    echo "unknown workaround: $id" >&2
    exit 1
  fi
  jq --arg id "$id" --arg date "$(date -I)" --arg note "$*" \
    '.[$id] = { checked: $date, note: $note }' "$notes" >"$notes.tmp"
  mv "$notes.tmp" "$notes"
  exit
fi

workarounds=$(nix eval --json .#workarounds)

# forget notes on removed workarounds
jq --argjson w "$workarounds" 'with_entries(select(.key | in($w)))' "$notes" >"$notes.tmp"
mv "$notes.tmp" "$notes"

jq -r --slurpfile notes "$notes" '
  to_entries
  | map(
      .key as $id
      | .value as $w
      | ($notes[0][$id] // {}) as $n
      | {
          $id,
          where: ($w.markers | join(" ")),
          state: (
            if $w.markers == [] then "unmarked"
            elif $w.fixed == true then "fixed"
            elif $w.fixed == null then "manual"
            else "pending" end
          ),
          checked: ($n.checked // ""),
          note: $n.note
        }
      | .age = (if .checked == "" then null
          else (now - (.checked | strptime("%Y-%m-%d") | mktime)) / 86400 | floor end)
    )
  | sort_by({ unmarked: 0, fixed: 1, manual: 2, pending: 3 }[.state], .checked, .id)
  | .[]
  | [
      .state,
      .id,
      .where,
      if .age != null then "\(.checked) (\(.age)d ago): \(.note)"
      elif .state == "manual" then "never checked"
      else "" end
    ]
  | @tsv
' <<<"$workarounds" | column -t -s $'\t'
