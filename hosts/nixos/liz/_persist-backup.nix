{
  config,
  lib,
  pkgs,
  sshKeys,
  ...
}:
let
  dataset = "rpool/persist";
  snapshot = "backup-staging";
  snapshotDir = "${config.utils.persistDir}/.zfs/snapshot/${snapshot}";
  outDir = "/tank/callum/backups";
  outFile = "${outDir}/liz-persist.tar.zst.age";

  recipients = pkgs.writeText "liz-persist-backup-recipients" (lib.concatLines sshKeys);

  # Relative to the snapshot root; globs are expanded by the shell.
  paths = [
    # host identity: sops decrypts with the SSH host key
    "etc/ssh"
    "etc/machine-id"
    "passwd"
    "var/lib/nixos"
    "var/lib/systemd/credential.secret"
    "var/lib/tailscale"
    "var/lib/samba"

    "data/qbittorrent"
    "data/radicale"
    "data/gitea"
    "data/leafwiki"
    "data/gotosocial"
    "data/technitium"
    "data/syncthing"
    "data/home-assistant"

    "data/media/jellyfin/config/config"
    "data/media/jellyfin/config/plugins"
    "data/media/jellyfin/config/root"
    "data/media/jellyfin/config/data/playlists"
    "data/media/jellyfin/config/data/jellyfin.db*"
  ];

  excludes = [
    "data/gotosocial/cache"
    "data/home-assistant/.cache"
    "data/home-assistant/backups"
    "data/home-assistant/deps"
    "data/home-assistant/tts"
    "data/home-assistant/home-assistant.log*"
    "data/home-assistant/home-assistant_v2.db*"
    "data/qbittorrent/qBittorrent/data/GeoDB"
    "data/qbittorrent/qBittorrent/data/logs"
    "data/syncthing/index-v2"
    "data/technitium/blocklists"
    "data/technitium/cache.bin"
    "data/technitium/logs"
    "data/technitium/stats"
  ];

  backup = pkgs.writeShellApplication {
    name = "liz-persist-backup";
    runtimeInputs = with pkgs; [
      age
      config.boot.zfs.package
      coreutils
      gnutar
      util-linux
      zstd
    ];
    text = ''
      # tank imports outside systemd's mount graph; never write to the ephemeral root
      mountpoint -q /tank/callum

      zfs destroy ${dataset}@${snapshot} 2>/dev/null || true
      zfs snapshot ${dataset}@${snapshot}
      tmp=
      # leave the snapshot's automount first, or it's busy
      trap 'cd /; rm -f "$tmp"; zfs destroy ${dataset}@${snapshot}' EXIT

      install -d -o callum -g users -m 0700 ${outDir}
      tmp=$(mktemp ${outFile}.XXXXXX)

      cd ${snapshotDir}
      # shellcheck disable=SC2086
      tar --create --numeric-owner --acls --xattrs \
        ${lib.concatMapStringsSep " " (e: "--exclude=${lib.escapeShellArg e}") excludes} \
        ${lib.concatStringsSep " " paths} \
        | zstd -T0 -10 \
        | age -R ${recipients} > "$tmp"

      chown callum:users "$tmp"
      chmod 0600 "$tmp"
      mv "$tmp" ${outFile}
    '';
  };
in
{
  systemd.services.liz-persist-backup = {
    description = "Encrypted archive of important /persist state into /tank/callum";
    after = [ "zfs-mount.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe backup;
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.liz-persist-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
