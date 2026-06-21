#!/usr/bin/env -S nix shell nixpkgs#nushell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#openssh nixpkgs#git --command nu

def interactive []: nothing -> bool {
    is-terminal --stdin
}

def ask-default [question: string, --default: string = ""]: nothing -> string {
    let resp = (input $"($question) [($default)]: " | str trim)
    if ($resp | is-empty) { $default } else { $resp }
}

def ask-required [question: string] {
    loop {
        let resp = (input $"($question): " | str trim)
        if ($resp | is-not-empty) { return $resp }
        print -e "  (a value is required)"
    }
}

def ask-yes-no [question: string, default: bool = true] {
    let hint = if $default { "[Y/n]" } else { "[y/N]" }
    loop {
        let resp = (input $"($question) ($hint) " | str trim | str downcase)
        if ($resp | is-empty) { return $default }
        match $resp {
            "y" | "yes" => { return true }
            "n" | "no" => { return false }
            _ => { print -e "  (please answer y or n)" }
        }
    }
}

def tri-state [yes: bool, no: bool, question: string, default: bool = true]: nothing -> bool {
    if ($yes and $no) {
        error make {msg: $"conflicting flags provided for: ($question)"}
    }
    if $yes { return true }
    if $no { return false }
    if (interactive) {
        ask-yes-no $question $default
    } else {
        error make {msg: $"non-interactive: pass the relevant flag to decide: ($question)"}
    }
}

def eval-ssh-key-path [flake_dir: string, hostname: string]: nothing -> record {
    let attr = $"($flake_dir)#nixosConfigurations.($hostname).config.sops.age.sshKeyPaths"
    let res = (^nix eval --raw $attr --apply "builtins.head" | complete)
    if $res.exit_code == 0 {
        {path: ($res.stdout | str trim), error: null}
    } else {
        {path: null, error: ($res.stderr | str trim)}
    }
}

def add-key-to-sops [sops_file: string, key_name: string, age_key: string]: nothing -> bool {
    let lines = (open --raw $sops_file | into string | lines)
    let anchors = ($lines | enumerate | where {|r| $r.item | str starts-with "  - &"})
    let aliases = ($lines | enumerate | where {|r| $r.item | str starts-with "      - *"})
    let age_headers = ($lines | where {|l| ($l | str trim) == "- age:"})
    if ($anchors | is-empty) or ($aliases | is-empty) or (($age_headers | length) > 1) {
        return false
    }

    let anchor_idx = ($anchors | last | get index)
    let alias_idx = ($aliases | last | get index)
    let anchor_line = $"  - &($key_name) ($age_key)"
    let alias_line = $"      - *($key_name)"

    # insert the alias first: it sits below the anchor, so the anchor index
    # stays valid after the alias has been inserted.
    let updated = (
        $lines
        | insert ($alias_idx + 1) $alias_line
        | insert ($anchor_idx + 1) $anchor_line
    )

    ($updated | str join "\n") + "\n" | save --force --raw $sops_file
    true
}

# Provision a new NixOS host for sops
#
# Generate a new SSH host key, convert it using ssh-to-age,
# add the recipient to .sops.yml in the secrets repo, re-encrypt,
# update the flake input, and optionally deploy using nixos-anywhere.
#
# Will try to evaluate the ssh-key-path based on the provided host's
# nixosConfiguration.
def main [
    --hostname: string        # used for evaluating options
    --key-name: string        # anchor label for the age key in .sops.yaml (default: hostname)
    --secrets-dir: string     # path to the nixos-secrets repo (default: ../nixos-secrets)
    --ssh-key-path: string    # path to the ssh key in the newly provisioned host
    --commit                  # commit the secrets repo
    --no-commit               # don't commit the secrets repo
    --push                    # push the secrets repo
    --no-push                 # don't push the secrets repo
    --update-input            # update the nixos-secrets input (if committed)
    --no-update-input         # don't update the nixos-secrets input
    --deploy-target: string   # if present, deploy to this ssh target with nixos-anywhere
] {
    let toplevel = (^git -C $env.PWD rev-parse --show-toplevel | complete)
    if $toplevel.exit_code != 0 {
        error make {msg: "not inside a git repository"}
    }

    let flake_dir = ($toplevel.stdout | str trim)
    if not ($flake_dir | path join "flake.nix" | path exists) {
        error make {msg: $"could not find flake.nix at ($flake_dir)"}
    }

    # fail fast before doing any work: conflicting flags are always an error,
    # and a non-interactive run must decide every commit/push/update via flags
    for d in [
        {yes: $commit, no: $no_commit, name: "--commit / --no-commit"}
        {yes: $push, no: $no_push, name: "--push / --no-push"}
        {yes: $update_input, no: $no_update_input, name: "--update-input / --no-update-input"}
    ] {
        if $d.yes and $d.no {
            error make {msg: $"conflicting flags: ($d.name)"}
        }
        if (not (interactive)) and (not $d.yes) and (not $d.no) {
            error make {msg: $"non-interactive run: ($d.name) must be set"}
        }
    }

    let hostname = if ($hostname | is-not-empty) {
        $hostname
    } else {
        ask-required "new host's hostname"
    }

    let eval = (eval-ssh-key-path $flake_dir $hostname)
    let eval_path = $eval.path
    let host_evaluated = ($eval_path | is-not-empty)
    if not $host_evaluated {
        print -e $"(ansi yellow)warning:(ansi reset) could not evaluate sops.age.sshKeyPaths for '($hostname)' \(undefined, untracked, or not using sops\)"
        print -e ($eval.error | default "(no error output)")
        print -e "if this host does use sops, pass --ssh-key-path explicitly."
        let cont = if (interactive) { ask-yes-no "continue anyway?" true } else { true }
        if not $cont { return }
    }

    let key_name = if ($key_name | is-not-empty) {
        $key_name
    } else if (interactive) {
        ask-default "anchor label for the age key" --default $hostname
    } else {
        $hostname
    }
    if not ($key_name =~ '^[A-Za-z0-9_-]+$') {
        error make {msg: $"invalid key name '($key_name)': use only letters, digits, '_' and '-'"}
    }

    let default_key_path = ($eval_path | default "/etc/ssh/ssh_host_ed25519_key")
    let ssh_key_path = if ($ssh_key_path | is-not-empty) {
        $ssh_key_path
    } else if (interactive) {
        ask-default "ssh host key path on the new machine" --default $default_key_path
    } else {
        $default_key_path
    }

    let default_secrets = ($flake_dir | path join ".." "nixos-secrets" | path expand)
    let secrets_dir = if ($secrets_dir | is-not-empty) {
        ($secrets_dir | path expand)
    } else if (interactive) {
        (ask-default "path to the nixos-secrets repo" --default $default_secrets | path expand)
    } else {
        $default_secrets
    }

    let sops_file = ($secrets_dir | path join ".sops.yaml")
    let secrets_yaml = ($secrets_dir | path join "secrets.yaml")
    for f in [$sops_file $secrets_yaml] {
        if not ($f | path exists) {
            error make {msg: $"missing ($f), is ($secrets_dir) the secrets repo?"}
        }
    }

    let sops_lines = (open --raw $sops_file | into string | lines)
    if ($sops_lines | any {|l| $l | str starts-with $"  - &($key_name) "}) {
        error make {msg: $"key '($key_name)' already exists in ($sops_file)"}
    }

    let tmp = (mktemp -d)

    let rel = ($ssh_key_path | str trim --left --char "/")
    let key_file = ($tmp | path join $rel)
    mkdir ($key_file | path dirname)
    let keygen = (^ssh-keygen -t ed25519 -N "" -C $"root@($hostname)" -f $key_file | complete)
    if $keygen.exit_code != 0 {
        error make {msg: $"ssh-keygen failed: ($keygen.stderr)"}
    }
    print -e $"generated host key at ($key_file)"

    let age = (^ssh-to-age -i $"($key_file).pub" | complete)
    if $age.exit_code != 0 {
        error make {msg: $"ssh-to-age failed: ($age.stderr)"}
    }
    let age_key = ($age.stdout | str trim)
    print -e $"age key: ($age_key)"

    let added = (add-key-to-sops $sops_file $key_name $age_key)
    if not $added {
        if (interactive) {
            print -e "could not insert automatically; opening the file in $EDITOR."
            print -e $"add to the keys list:\n  - &($key_name) ($age_key)"
            print -e $"and to the age list:\n      - *($key_name)"
            let editor = ($env.EDITOR? | default "vi")
            ^$editor $sops_file
        } else {
            error make {msg: $"could not auto-insert the key into ($sops_file) and cannot prompt (non-interactive)"}
        }
    }

    ^git -C $secrets_dir --no-pager diff -- .sops.yaml
    if (interactive) {
        if not (ask-yes-no "does .sops.yaml look correct?" true) {
            let editor = ($env.EDITOR? | default "vi")
            ^$editor $sops_file
        }
    }

    if not (open --raw $sops_file | into string | lines | any {|l| $l | str starts-with $"  - &($key_name) "}) {
        error make {msg: $"key '($key_name)' is not present in ($sops_file); aborting before re-encrypt"}
    }

    print -e "re-encrypting secrets.yaml (sops updatekeys)..."
    let upd = (^sops --config $sops_file updatekeys --yes $secrets_yaml | complete)
    if $upd.exit_code != 0 {
        error make {msg: $"sops updatekeys failed: ($upd.stderr)"}
    }

    let do_commit = (tri-state $commit $no_commit "commit the secrets repo?" true)
    if not $do_commit {
        print -e $"changes left uncommitted in ($secrets_dir)."
        print -e $"host key generated at ($tmp) \(remember to remove it after deploying\)"
        return
    }
    let add = (^git -C $secrets_dir add .sops.yaml secrets.yaml | complete)
    if $add.exit_code != 0 {
        error make {msg: $"git add failed: ($add.stderr)"}
    }
    let commit = (^git -C $secrets_dir commit -m $"add sops host: ($key_name)" | complete)
    if $commit.exit_code != 0 {
        error make {msg: $"git commit failed: ($commit.stderr)($commit.stdout)"}
    }
    print -e "committed."

    let do_push = (tri-state $push $no_push "push the secrets repo?" true)
    if $do_push {
        let p = (^git -C $secrets_dir push | complete)
        if $p.exit_code != 0 {
            error make {msg: $"git push failed: ($p.stderr)"}
        }
        print -e "pushed."
    }

    let do_update = (tri-state $update_input $no_update_input "update the nixos-secrets flake input?" $do_push)
    mut override_secrets = false
    if not $do_update {
        if $do_push {
            print -e $"to update later, run: nix flake update secrets"
        } else {
            print -e $"secrets not pushed; deploy with: nix flake update secrets --override-input secrets path:($secrets_dir)"
        }
        print -e $"host key generated at ($tmp) \(remember to remove it after deploying\)"
        return
    }
    if $do_push {
        let u = (^nix flake update secrets --flake $flake_dir | complete)
        if $u.exit_code != 0 {
            error make {msg: $"nix flake update secrets failed: ($u.stderr)"}
        }
        print -e "flake input 'secrets' updated."
    } else {
        $override_secrets = true
        print -e $"(ansi yellow)note:(ansi reset) secrets not pushed; deploy will use --override-input secrets path:($secrets_dir)"
    }

    let override_args = if $override_secrets {
        ["--override-input" "secrets" $"path:($secrets_dir)"]
    } else {
        []
    }
    let do_deploy = if ($deploy_target | is-not-empty) {
        true
    } else if $host_evaluated and (interactive) {
        ask-yes-no $"deploy ($hostname) now with nixos-anywhere?" false
    } else {
        false
    }
    let target = if ($deploy_target | is-not-empty) {
        $deploy_target
    } else if $do_deploy {
        ask-required "deploy target (user@host)"
    } else {
        null
    }

    if $do_deploy {
        print -e $"deploying ($hostname) to ($target)..."
        let ok = (try {
            do {
                cd $flake_dir
                ^nix run nixpkgs#nixos-anywhere -- --flake $".#($hostname)" --extra-files $tmp --target-host $target ...$override_args
            }
            true
        } catch { false })
        if $ok {
            rm -rf $tmp
            print -e "done."
        } else {
            let cmd = (
                ["nix" "run" "nixpkgs#nixos-anywhere" "--" "--flake" $".#($hostname)" "--extra-files" $tmp "--target-host" $target]
                | append $override_args
                | str join " "
            )
            print -e $"(ansi red)deploy failed.(ansi reset) the host key is kept at ($tmp)"
            print -e $"retry \(from ($flake_dir)\): ($cmd)"
        }
    } else {
        let cmd = (
            ["nix" "run" "nixpkgs#nixos-anywhere" "--" "--flake" $".#($hostname)" "--extra-files" $tmp "--target-host" ($target | default "<user@host>")]
            | append $override_args
            | str join " "
        )
        print -e $"to deploy, run \(from ($flake_dir)\):"
        print -e $"  ($cmd)"
        print -e $"afterwards remove the temp dir: rm -rf ($tmp)"
    }
}
