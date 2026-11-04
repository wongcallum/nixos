{ lib, ... }:
let
  target = "eberouge";
  user = "liz-backup";
  keep = {
    daily = 7;
    weekly = 4;
    monthly = 6;
  };
  maxBytes = 4 * 1024 * 1024 * 1024;

  sourceHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0RmYquUGDKZ0YK22IbfUoa8BStIls3p0hoFx1iSpTS root@liz";
  targetHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWTAAbkjTRkisqJf/6sQTO+4eO4fepneZPH7JgQ/bjO root@eberouge";

  heartbeat = {
    group = "liz";
    name = "offsite-backup";
    # Posted from localhost, and it can only fake a heartbeat.
    token = "liz-offsite-backup-5b0e92d4";
  };
in
{
  flake.modules.nixos = {
    offsite-backup-target =
      { config, pkgs, ... }:
      let
        dir = config.utils.dataDir user;
        receive = pkgs.writeShellApplication {
          name = "offsite-backup-receive";
          runtimeInputs = with pkgs; [
            coreutils
            curl
            findutils
          ];
          text = ''
            want=''${SSH_ORIGINAL_COMMAND:-}
            if [[ ! $want =~ ^[0-9a-f]{64}$ ]]; then
              echo "usage: ssh ${user}@${target} <sha256> < archive" >&2
              exit 2
            fi

            tmp=$(mktemp ${dir}/.incoming.XXXXXX)
            trap 'rm -f "$tmp"' EXIT
            head -c ${toString (maxBytes + 1)} > "$tmp"

            if (( $(stat -c %s "$tmp") > ${toString maxBytes} )); then
              echo "archive is over ${toString maxBytes} bytes" >&2
              exit 1
            fi
            if [[ $(sha256sum "$tmp" | cut -d' ' -f1) != "$want" ]]; then
              echo "checksum mismatch" >&2
              exit 1
            fi
            if [[ $(head -c 21 "$tmp") != age-encryption.org/v1 ]]; then
              echo "not an age file" >&2
              exit 1
            fi

            sync "$tmp"
            mv "$tmp" "${dir}/liz-persist-$(date +%F).tar.zst.age"
            trap - EXIT
            sync ${dir}

            # Like restic's --keep-{daily,weekly,monthly}: the newest archive of each
            # recent day, ISO week and month survives.
            declare -A weeks=() months=()
            days=0
            while read -r f; do
              day=''${f#liz-persist-}
              day=''${day%%.*}
              week=$(date -d "$day" +%G-%V)
              month=''${day:0:7}
              keep=
              if (( days < ${toString keep.daily} )); then
                keep=1
              fi
              if [[ -z ''${weeks[$week]:-} ]] && (( ''${#weeks[@]} < ${toString keep.weekly} )); then
                weeks[$week]=1
                keep=1
              fi
              if [[ -z ''${months[$month]:-} ]] && (( ''${#months[@]} < ${toString keep.monthly} )); then
                months[$month]=1
                keep=1
              fi
              days=$((days + 1))
              [[ -n $keep ]] || rm -- "${dir}/$f"
            done < <(find ${dir} -maxdepth 1 -name 'liz-persist-*.tar.zst.age' -printf '%f\n' | sort -r)

            curl -fsS -X POST -H "Authorization: Bearer ${heartbeat.token}" \
              "http://127.0.0.1:${toString config.services.gatus.settings.web.port}/api/v1/endpoints/${heartbeat.group}_${heartbeat.name}/external?success=true" \
              >/dev/null || echo "stored, but couldn't report to Gatus" >&2
            echo stored
          '';
        };
      in
      {
        users.groups.${user} = { };
        users.users.${user} = {
          isSystemUser = true;
          group = user;
          # sshd runs the forced command through the login shell.
          useDefaultShell = true;
          openssh.authorizedKeys.keys = [ ''restrict,command="${lib.getExe receive}" ${sourceHostKey}'' ];
        };

        systemd.tmpfiles.rules = [ "d ${dir} 0700 ${user} ${user} -" ];

        services.gatus.settings.external-endpoints = [
          {
            inherit (heartbeat) name group token;
            heartbeat.interval = "26h";
            alerts = [
              {
                type = "telegram";
                failure-threshold = 1;
                description = "No liz backup has reached ${target} in 26 hours";
              }
            ];
          }
        ];
      };

    offsite-backup-source =
      { config, pkgs, ... }:
      let
        cfg = config.modules.offsiteBackup;
        addr = config.modules.hostAddrs.${target};
        send = pkgs.writeShellApplication {
          name = "offsite-backup-send";
          runtimeInputs = with pkgs; [
            coreutils
            openssh
          ];
          text = ''
            # Hash and send the same inode, even if the next backup replaces the path.
            exec 3< ${cfg.file}
            sum=$(sha256sum /dev/fd/3 | cut -d' ' -f1)
            ssh -i ${config.utils.persistDir}/etc/ssh/ssh_host_ed25519_key \
              -o BatchMode=yes -o IdentitiesOnly=yes \
              -o ConnectTimeout=30 -o ServerAliveInterval=30 \
              ${user}@${addr} "$sum" < /dev/fd/3
          '';
        };
      in
      {
        options.modules.offsiteBackup.file = lib.mkOption {
          type = lib.types.str;
          description = "Encrypted archive to copy to ${target}";
        };

        config = {
          programs.ssh.knownHosts.${target} = {
            hostNames = [
              target
              addr
            ];
            publicKey = targetHostKey;
          };

          systemd.services.offsite-backup = {
            description = "Copy the encrypted backup archive to ${target}";
            wants = [ "network-online.target" ];
            after = [
              "network-online.target"
              "tailscaled.service"
            ];
            startLimitBurst = 4;
            startLimitIntervalSec = 7200;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe send;
              Restart = "on-failure";
              RestartSec = "15min";
              Nice = 19;
              IOSchedulingClass = "idle";
            };
          };
        };
      };
  };
}
