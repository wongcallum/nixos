---
name: check-workarounds
description: Research whether the manual workarounds in modules/workarounds.nix can be removed yet, and record the findings.
disable-model-invocation: true
---

# Check workarounds

Each manual workaround asks one question: does its `done` condition hold **in the lock**, meaning at the revisions `flake.lock` pins? A fix merged upstream but not yet in the lock leaves the workaround in place.

## Steps

1. Run `scripts/workarounds.sh`.
2. Choose the entries the user named. If they named none, choose every `manual` row that was never checked or was last checked more than 30 days ago. Carry any `fixed` or `unmarked` rows straight into the report; they need cleanup, not research.
3. Settle each chosen entry. Read its `upstream`, `done` and marked code, then find the **delta** since its last note: comments, commits and releases after that date (see [Reading upstream](#reading-upstream)). An entry is settled when every clause of `done` is answered true or false, with evidence. With subagents, dispatch one per entry, each returning its finding as one line.
4. Record each finding with `scripts/workarounds.sh note <id> "<finding>"` (see [Where findings go](#where-findings-go)). This step is done when rerunning the script shows today's date on every chosen row.
5. Report one table row per chosen entry: id, verdict, and one line of evidence. The verdicts are:
   - **removable**: `done` holds in the lock.
   - **progress**: closer than last time, e.g. merged but not in the lock yet.
   - **unchanged**: nothing has moved.
   - **needs you**: a decision for the user, such as filing upstream.

The run ends at the report. Removal follows only on request, as described in AGENTS.md.

## Reading upstream

Treat upstream as **read-only**. When a report or PR should exist, the verdict is **needs you**.

- **Commits in the lock:** get the locked rev with `nix flake metadata --json | jq -r '.locks.nodes."<input>".locked.rev'`. Then `gh api repos/<owner/repo>/compare/<fix-sha>...<locked-rev> -q .status` prints `ahead` or `identical` when the lock contains the fix. For nixpkgs, compare against the input the host follows (`nixpkgs` or `unstable-upstream`), because `unstable` is our patched fork.
- **Versions in the lock:** `nix eval --inputs-from . --raw <input>#<attr>.version`.
- **Source in the lock:** run `nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.<name>.outPath'`, then read files under that path.
- **Trackers outside GitHub:**
  - bugs.kde.org: `/rest/bug/<id>` and `/rest/bug/<id>/comment`.
  - lore.kernel.org: the thread at `<message-url>/T/`.
  - Forgejo or Gitea: commits at `/api/v1/repos/<owner>/<repo>/commits?sha=<branch>&path=<file>`.
- **Nothing filed upstream:** look for an independent fix in recent commits that touch the affected code.

## Where findings go

- **Note:** one line giving the evidence, what's still missing, and the links or short revs the next check starts from. For example: `PR merged 2026-10-01 as 1a2b3c4; not in unstable-upstream (a7868a7) yet`.
- **Definition:** lasting changes, such as a newly filed report (`upstream`) or a fix that takes a different shape (`done`).
- **`fixed` check:** when `done` can now be evaluated from the lock, for example because the fix ships in a known release, propose a `fixed` check so CI takes over the entry.
